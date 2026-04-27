
import Foundation
import Combine
import SwiftUI

// MARK: - App Bootstrap Application Logic
extension TradingViewModel {
    
    /// Call this once on App launch. Idempotent.
    /// OPTIMIZED: Ağır işlemler geciktirildi, UI hemen açılıyor
    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        
        let startTime = Date()
        let signpost = SignpostLogger.shared
        let id = signpost.begin(log: signpost.startup, name: "BOOTSTRAP")
        
        // DEBUG dump KALDIRILDI - Performans için
        
        defer { 
            signpost.end(log: signpost.startup, name: "BOOTSTRAP", id: id) 
            let duration = Date().timeIntervalSince(startTime)
            ArgusLogger.bootstrapComplete(seconds: duration)
            Task { @MainActor in DiagnosticsViewModel.shared.recordBootstrapDuration(duration) }
        }
        
        // PHASE 1: HIZLI - UI'ı bloklamayan işlemler (~100ms hedef)
        // ---------------------------------------------------------
        // MARK: - 1. Legacy Persistence Load (Removed)
        // Stores (WatchlistStore, PortfolioStore) initialize themselves.

        
        // BIST Bakiye Tutarlılık Kontrolü (Gerekirse düzelt, sıfırlama YAPMA)
        // Not: resetBistPortfolio() KALDIRILDI - bu debug koduydu ve her açılışta 
        // tüm BIST portföyünü sıfırlıyordu!
        // recalculateBistBalance() // Sadece tutarsızlık varsa bunu etkinleştir
        
        // Setup SSoT Bindings (Memory - hızlı)
        setupStoreBindings()
        
        ArgusLogger.success(.bootstrap, "Faz 1: UI hazır")
        
        // PHASE 2: Stream + polling priority tier — hemen başlar.
        // Stream WebSocket; HTTP burst yapmaz, Yahoo cap'ini yemez.
        // Polling Tier 1 (~30 sembol) chunked 4@1.1s → 3.6 r/s, ~8sn'de tamam.
        // ---------------------------------------------------------
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // RL-Lite: Tune System based on history
            ArgusFeedbackLoopService.shared.tuneSystem(history: self.portfolio)

            // Enable Live Mode
            self.isLiveMode = true

            // Connect Stream for Watchlist (WebSocket, ücretsiz cap)
            ArgusLogger.phase(.veri, "Faz 2: Stream bağlanıyor...")
            self.marketDataProvider.connectStream(symbols: self.watchlist)
        }

        // PHASE 3: Scout/Watchlist polling — Tier 1 fetch hemen, UI bloklamaz.
        // ---------------------------------------------------------
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // BorsaPy Warm-Up: Render.com free tier uyku modundan çıkar
            Task.detached(priority: .background) {
                ArgusLogger.phase(.veri, "BorsaPy: Backend ısındırılıyor...")
                await BorsaPyProvider.shared.warmUp()
            }

            ArgusLogger.phase(.autopilot, "Faz 3: Scout + Watchlist döngüsü başlatılıyor...")
            self.startScoutLoop()
            self.startWatchlistLoop()

            // AutoPilot ML — Tier 1 fetch'in (~8sn) tamamlanmasına süre tanıyıp
            // ondan sonra başlasın. Aynı saniyede ağ üstüne çıkmasın.
            Task.detached(priority: .utility) {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                await MainActor.run {
                    AutoPilotStore.shared.startAutoPilotLoop()
                }
            }
        }

        // PHASE 4: Atlas/Demeter — Tier 1 priority fetch tamamlandıktan sonra
        // background'a düşsün. Aksi halde watchlist + Atlas paralel candle
        // çağrıları aynı 60s pencereyi paylaşıp kotayı yer.
        // ---------------------------------------------------------
        Task.detached(priority: .background) { [weak self] in
            // ~10sn: Tier 1 (~8sn) bitsin + 2sn marj. Bu süre içinde Stream
            // zaten quote akışı sağlıyor, kullanıcı boş ekran görmüyor.
            try? await Task.sleep(nanoseconds: 10_000_000_000)

            guard let self = self else { return }

            ArgusLogger.phase(.atlas, "Faz 4: Atlas/Demeter başlatılıyor...")
            await self.hydrateAtlas()
            await self.runDemeterAnalysis()

            // Quota Reset (artık acil değil)
            await QuotaLedger.shared.reset(provider: "Finnhub")
            await QuotaLedger.shared.reset(provider: "Yahoo")
            await QuotaLedger.shared.reset(provider: "Yahoo Finance")
        }
        
        ArgusLogger.info(.bootstrap, "Lazy loading aktif")
    }
    

    
    // MARK: - Data Loading
    
    func loadData() {
        isLoading = true
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.ui, name: "LoadData")
        
        Task {
             ArgusLogger.phase(.veri, "Paralel veri yüklemesi...")
             
             // 1. High Priority: Prices (Watchlist + Safe Cards)
             // Run concurrently
             // 'fetchQuotes' already includes Safe Assets and Watchlist.
             async let quotesJob: () = fetchQuotes()
             
             // Wait for prices
             _ = await quotesJob
             
             // UI Unblock: Show prices immediately
             await MainActor.run { self.isLoading = false }
             
             // 2. Medium Priority: History (Candles)
             // This can take time (has rate limit delays)
             await fetchCandles()
             
             // 3. Low Priority: Intelligence (Signals, Macro, Discover)
             // These depend on Candles/Quotes
             
             async let aiJob: () = generateAISignals()
             async let macroJob: () = MainActor.run { loadMacroEnvironment() }
             async let discoverJob: () = MainActor.run { loadDiscoverData() }
             async let losersJob: () = fetchTopLosers()
             async let demeterJob: () = runDemeterAnalysis()
             
             _ = await (aiJob, macroJob, discoverJob, losersJob, demeterJob)
             
             SignpostLogger.shared.end(log: SignpostLogger.shared.ui, name: "LoadData", id: spanId)
        }
    }
}
