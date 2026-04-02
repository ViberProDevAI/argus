//
//  argusApp.swift
//  argus
//
//  Created by Argus Team on 30.01.2026.
//

import SwiftUI
import SwiftData

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

    init() {
        do {
            let modelContainer = try ModelContainer(for: ShadowTradeSession.self, MissedOpportunityLog.self)
            self.container = modelContainer
            
            // SETUP NOTIFICATION DELEGATE
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            
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
