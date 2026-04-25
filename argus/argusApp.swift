//
//  argusApp.swift
//  argus
//
//  Created by Argus Team on 30.01.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct argusApp: App {
    // Create container manually to access context easily for Singleton injection
    let container: ModelContainer

    // Static timer holder to prevent memory leaks from multiple timer instances
    private static var maturationTimer: Timer?
    private static var cleanupTimer: Timer?
    private static var ragRetryTimer: Timer?

    // Unified Singleton ViewModel (Legacy - Geçiş döneminde korunuyor)
    @StateObject private var tradingViewModel = TradingViewModel()

    // FAZ 2: Yeni modüler koordinatör (Paralel çalışıyor)
    @StateObject private var coordinator = AppStateCoordinator.shared

    // Intro State
    @State private var showIntro = true

    // O1: Scene lifecycle — `.background`/`.inactive` geçişlerinde PortfolioStore
    // diski senkron yazar. Debounced save'in 1 sn'lik penceresinde app suspend
    // olursa son mutasyon kayboluyordu; bu observer kaybı önler.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let modelContainer = try ModelContainer(for: ShadowTradeSession.self, MissedOpportunityLog.self)
            self.container = modelContainer
            
            // SETUP NOTIFICATION DELEGATE
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

            // O1: App terminate anında son bir kez diski yaz. scenePhase
            // observer'ı çoğu durumu kapsar (swipe-to-quit background'a geçirir),
            // bu observer sistem terminate yaptığı nadir senaryolar için
            // belt-and-suspenders savunmadır. queue: .main garantisi ile main
            // thread'de fire eder — `MainActor.assumeIsolated` ile @MainActor
            // method'unu senkron çağırırız (Task ile asenkron dispatch yapamayız;
            // notification fire ile app termination arasında saniye bile yok).
            NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    PortfolioStore.shared.flushNow()
                }
            }

            // Keychain güvenlik temizliği: eski sürümlerde UserDefaults'ta plaintext
            // kalmış olabilecek API anahtarlarını Keychain'e taşı ve UserDefaults'ı temizle.
            KeychainManager.shared.migrateLegacyUserDefaultsKeys()

            // Inject into Singleton immediately
            Task { @MainActor in
                LearningPersistenceManager.shared.setContext(modelContainer.mainContext)

                print("📂 PortfolioStore: Mevcut portfolyo yukleniyor...")
                
                // AUTO CLEANUP: Storage temizliği (günde 1 kez)
                await ArgusLedger.shared.autoCleanupIfNeeded()
                DiskCacheService.shared.cleanup()
                
                // CHIRON CLEANUP: RAG sync edilmiş 7 günden eski kayıtları sil
                let _ = await ChironDataLakeService.shared.cleanupSyncedRecords(olderThanDays: 7)
            }
        } catch {
            print("🚨 CRITICAL: Failed to create ModelContainer: \(error)")
            // FALLBACK: Create in-memory container to prevent crash
            do {
                let schema = Schema([ShadowTradeSession.self, MissedOpportunityLog.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try ModelContainer(for: schema, configurations: [config])
                print("⚠️ Using In-Memory Safe Container")
            } catch let fallbackError {
                print("🚨 FATAL FALLBACK FAILED: \(fallbackError)")
                print("🛡️ Using minimal empty container - some features may be unavailable")

                // Son çare: boş schema ile in-memory container
                // fatalError KULLANILMAZ — App Store reddi ve launch crash riski
                if let lastResort = try? ModelContainer(for: Schema([]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]) {
                    self.container = lastResort
                } else {
                    // Buraya asla ulaşılmamalı — tüm fallback'ler başarısız
                    // fatalError yerine en azından crash log bırak ve graceful exit
                    print("🛑 Tüm ModelContainer fallback'leri başarısız. Uygulama çalışamaz.")
                    self.container = try! ModelContainer(for: Schema([ShadowTradeSession.self, MissedOpportunityLog.self]),
                        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                }
            }
        }
    }

    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer: Bool = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showIntro {
                    SplashScreenView {
                        withAnimation {
                            showIntro = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                } else {
                    if !hasSeenOnboarding {
                        ArgusOnboardingView {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }
                        .transition(.opacity)
                    } else if hasAcceptedDisclaimer {
                        ContentView()
                            .environmentObject(tradingViewModel)
                            .environmentObject(coordinator)
                            .environmentObject(coordinator.watchlist)
                            .environmentObject(coordinator.portfolio)
                            .task {
                                // One-time startup logic
                                tradingViewModel.bootstrap()

                                // 🧠 Chiron: Start background learning analysis
                                Task.detached(priority: .background) {
                                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                                    await ChironLearningJob.shared.runFullAnalysis()
                                    print("🧠 Chiron: Startup learning cycle completed")
                                }

                                // 👁️ Alkindus: Start periodic maturation checks
                                startAlkindusPeriodicCheck()
                                
                                // 🧹 Argus Cleanup: Start periodic aggressive cleanup
                                startAutomaticCleanup()
                                
                                // 📅 ReportScheduler: Otomatik rapor oluşturmayı başlat
                                Task.detached(priority: .background) {
                                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                                    await ReportScheduler.shared.start()
                                    print("📅 ReportScheduler: Başlatıldı (5 saniye gecikme)")
                                }
                            }
                            .transition(.opacity)
                    } else {
                        DisclaimerView()
                            .transition(.opacity)
                    }
                }
            }
        }
        .modelContainer(container)
        // O1: scenePhase observer — background/inactive geçişlerinde diski yaz.
        // .background: app tam olarak arka plana geçti (user home, app switcher, başka app).
        // .inactive: geçiş anı (pull-down notification center, locking, incoming call).
        // Her ikisinde de flush ediyoruz — save operasyonu ucuz (3 JSON file, main thread),
        // debounce bekleyen bir yazma varsa bu noktada garantiye alınır.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                PortfolioStore.shared.flushNow()
            }
        }
    }

    // MARK: - Alkindus Periodic Check

    private func startAlkindusPeriodicCheck() {
        Self.maturationTimer?.invalidate()

        Task.detached(priority: .background) {
            // Chiron: geçmiş işlemlerden öğren (soğuk başlangıç kurtarma)
            await ChironLearningSystem.shared.bootstrapFromHistory()
        }

        Task.detached(priority: .background) {
            do {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                await AlkindusCalibrationEngine.shared.periodicMatureCheck()
                print("Alkindus: Startup maturation check completed")
            } catch {
                print("Alkindus maturation check failed: \(error)")
            }
        }

        // RAG Retry: Açılışta bekleyen başarısız sync'leri tekrar dene
        Task.detached(priority: .background) {
            do {
                // Maturation'dan sonra başlasın (20 sn gecikme)
                try await Task.sleep(nanoseconds: 20_000_000_000)
                let pending = await AlkindusSyncRetryQueue.shared.queueCount()
                if pending > 0 {
                    print("Info: Alkindus RAG: \(pending) bekleyen sync bulundu, yeniden deneniyor...")
                    await AlkindusSyncRetryQueue.shared.processRetryQueue()
                }
            } catch {
                print("Alkindus RAG retry failed: \(error)")
            }
        }

        Self.maturationTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await AlkindusCalibrationEngine.shared.periodicMatureCheck()
                // Saatlik maturation sonrası RAG retry da çalışsın
                await AlkindusSyncRetryQueue.shared.processRetryQueue()
            }
        }

        // RAG Retry: Her 6 saatte bir bağımsız retry (internet geç geldiyse)
        Self.ragRetryTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { _ in
            Task.detached(priority: .background) {
                let pending = await AlkindusSyncRetryQueue.shared.queueCount()
                if pending > 0 {
                    print("Info: Alkindus RAG: Periyodik retry - \(pending) bekleyen")
                    await AlkindusSyncRetryQueue.shared.processRetryQueue()
                }

                // Opportunity Cost değerlendirmesi — 7 günü geçen bekleyen kayıtları değerlendir
                let prices: [String: Double] = await MainActor.run {
                    Dictionary(uniqueKeysWithValues:
                        MarketDataViewModel.shared.quotes.compactMap { (sym, q) -> (String, Double)? in
                            guard q.currentPrice > 0 else { return nil }
                            return (sym, q.currentPrice)
                        }
                    )
                }
                if !prices.isEmpty {
                    await OpportunityCostTracker.shared.evaluateMatureOpportunities(currentPrices: prices)
                    let signal = await OpportunityCostTracker.shared.calibrationSignal()
                    print("💰 Opportunity Cost Kalibrasyon: \(signal.description)")
                }
            }
        }
    }
    
    // MARK: - Automatic Storage Cleanup
    
    private func startAutomaticCleanup() {
        Self.cleanupTimer?.invalidate()
        
        Task.detached(priority: .background) {
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                await ArgusLedger.shared.aggressiveCleanup()
                print("🧹 Argus: Startup cleanup completed")
            } catch {
                print("Argus cleanup failed: \(error)")
            }
        }
        
        Self.cleanupTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { _ in
            Task {
                await ArgusLedger.shared.aggressiveCleanup()
                print("🧹 Argus: Periodic cleanup completed")
            }
        }
    }
}
