import Foundation

// MARK: - Trade Brain Plan Execution Engine
/// Pozisyon planlarını otomatik kontrol eder ve tetiklenen aksiyonları uygular

extension TradingViewModel {

    // MARK: - Plan Trigger Kontrolü

    /// Tüm açık pozisyonların planlarını kontrol et
    /// Bu fonksiyon AutoPilot döngüsünde veya quote güncellemelerinde çağrılmalı
    func checkPlanTriggers() async {
        let openTrades = portfolio.filter { $0.isOpen }
        
        guard !openTrades.isEmpty else { return }
        
        for trade in openTrades {
            guard let currentPrice = quotes[trade.symbol]?.currentPrice, currentPrice > 0 else {
                continue
            }
            
            // Council kararını al (varsa) - TradingViewModel'den
            let grandDecision = await MainActor.run { self.grandDecisions[trade.symbol] }
            
            // Plan tetikleyicilerini kontrol et
            if let triggeredAction = PositionPlanStore.shared.checkTriggers(
                trade: trade,
                currentPrice: currentPrice,
                grandDecision: grandDecision
            ) {
                // Tetiklenen aksiyon bulundu!
                await handleTriggeredAction(
                    trade: trade,
                    action: triggeredAction,
                    currentPrice: currentPrice
                )
            }
        }
    }
    
    // MARK: - Aksiyon Uygulama
    
    /// Tetiklenen plan aksiyonunu uygula
    private func handleTriggeredAction(
        trade: Trade,
        action: PlannedAction,
        currentPrice: Double
    ) async {
        
        // Adımı tamamlandı olarak işaretle (tekrar tetiklenmesini önle)
        PositionPlanStore.shared.markStepCompleted(tradeId: trade.id, stepId: action.id)
        
        // Aksiyon tipine göre işlem yap
        switch action.action {
        case .sellAll:
            // Tamamını sat
            await executePlanSell(
                trade: trade,
                percentage: 100,
                currentPrice: currentPrice,
                reason: "📋 Plan: \(action.description)"
            )
            
        case .sellPercent(let percent):
            // Yüzde sat
            await executePlanSell(
                trade: trade,
                percentage: percent,
                currentPrice: currentPrice,
                reason: "📋 Plan: \(action.description)"
            )
            
        case .alert(let message):
            // KULLANICI İSTEĞİ: Gereksiz bildirimleri engellemek için kapatıldı.
            // Sadece log basıyoruz.
            print("🔔 Trade Brain Alert (Sessiz): \(trade.symbol) - \(message)")
            /*
            await registerPlanAlert(
                symbol: trade.symbol,
                message: message,
                action: action
            )
            */
            
        case .reevaluate:
            // KULLANICI İSTEĞİ: "Karar" bildirimleri kapatıldı.
            print("🤔 Trade Brain Re-evaluate (Sessiz): \(trade.symbol) - \(action.description)")
            /*
            await registerPlanAlert(
                symbol: trade.symbol,
                message: "Pozisyonu yeniden değerlendir: \(action.description)",
                action: action
            )
            */
            
        case .reduceAndHold(let percent):
            // Azalt ve tut
            await executePlanSell(
                trade: trade,
                percentage: percent,
                currentPrice: currentPrice,
                reason: "📋 Plan: Azalt ve tut - \(action.description)"
            )
            
        case .moveStopTo(let newStop):
            // Stop seviyesini güncelle (Trade üzerinde)
            await updateTradeStop(tradeId: trade.id, newStop: newStop)
            print("🛡️ Trade Brain: Stop güncellendi \(trade.symbol) → \(String(format: "%.2f", newStop))")
            
        case .moveStopByPercent, .activateTrailingStop, .setBreakeven:
            // Stop yönetimi aksiyonları - ileride implement edilecek
            print("⚠️ Trade Brain: Stop yönetimi aksiyonları henüz desteklenmiyor")
            
        case .addPercent, .addFixed:
            // Alım işlemleri - şu an desteklenmiyor (riskli)
            print("⚠️ Trade Brain: Alım aksiyonları henüz desteklenmiyor")
            
        case .doNothing:
            // Hiçbir şey yapma
            break
        }
    }
    
    // MARK: - Satış Uygulama
    
    /// Plan bazlı satış işlemi
    private func executePlanSell(
        trade: Trade,
        percentage: Double,
        currentPrice: Double,
        reason: String
    ) async {
        let quantityToSell = trade.quantity * (percentage / 100.0)
        
        if percentage >= 100 {
            // Tamamını sat
            await MainActor.run {
                self.sell(
                    tradeId: trade.id,
                    currentPrice: currentPrice,
                    reason: reason
                )
            }
            
            // Planı tamamla
            PositionPlanStore.shared.completePlan(tradeId: trade.id)
            
            print("🧠 Trade Brain: \(trade.symbol) TAMAMINI SATTI @ \(String(format: "%.2f", currentPrice))")
        } else {
            // Kısmi satış
            await MainActor.run {
                self.sellPartial(
                    tradeId: trade.id,
                    quantity: quantityToSell,
                    currentPrice: currentPrice,
                    reason: reason
                )
            }
            
            print("🧠 Trade Brain: \(trade.symbol) %\(Int(percentage)) SATTI (\(String(format: "%.2f", quantityToSell)) adet) @ \(String(format: "%.2f", currentPrice))")
        }
    }
    
    // MARK: - Bildirim Kayıt
    
    /// Plan bildirimi kaydet (UI'da göstermek için)
    @MainActor
    func registerPlanAlert(
        symbol: String,
        message: String,
        action: PlannedAction
    ) {
        let alert = TradeBrainAlert(
            type: .planTriggered,
            symbol: symbol,
            message: message,
            actionDescription: action.description,
            priority: .medium
        )
        
        ExecutionStateViewModel.shared.planAlerts.append(alert)
        
        // 50'den fazla alert varsa eskileri sil
        if ExecutionStateViewModel.shared.planAlerts.count > 50 {
            ExecutionStateViewModel.shared.planAlerts = Array(ExecutionStateViewModel.shared.planAlerts.suffix(50))
        }
        
        print("🔔 Trade Brain Alert: \(symbol) - \(message)")
    }
    
    // MARK: - Stop Güncelleme
    //
    // ÖNEMLİ (K1 fix): SL/TP güncellemesi yalnızca `PortfolioStore`'un SSoT'u
    // üzerinden yapılır. Eskiden `portfolio[index].stopLoss = newStop` ile lokal
    // @Published kopyaya yazılıyordu; Combine bir sonraki tick'te PortfolioStore'un
    // eski SL'ini geri yayımladığı için koruma eski seviyede kalıyordu.
    private func updateTradeStop(tradeId: UUID, newStop: Double) async {
        await MainActor.run {
            _ = PortfolioStore.shared.updateStops(tradeId: tradeId, newStop: newStop)
        }
    }
    
    // MARK: - Kısmi Satış Helper
    //
    // ÖNEMLİ (K2 fix): Kısmi satış yalnızca `PortfolioStore.trimByQuantity` üzerinden yapılır.
    // Eskiden local `portfolio[index]`, `balance`, `bistBalance`, `transactionHistory`
    // alanlarına yazılıyordu; bu alanlar PortfolioStore'un Combine publisher'larından
    // beslendiği için bir sonraki quote tick'inde yazım geri alınıyor, satış "hayalet"
    // işleme dönüşüyordu (toast başarılı, disk'te iz yok, bir sonraki buy/sell eski
    // quantity üzerinden hareket ediyordu).
    //
    // Commission + transaction kaydı + persist + publish artık tek bir atomik çağrıda:
    func sellPartial(
        tradeId: UUID,
        quantity: Double,
        currentPrice: Double,
        reason: String
    ) {
        let pnl = PortfolioStore.shared.trimByQuantity(
            tradeId: tradeId,
            quantity: quantity,
            currentPrice: currentPrice,
            reason: reason
        )
        if pnl == nil {
            print("❌ sellPartial reddedildi: tradeId=\(tradeId) quantity=\(quantity) (yetersiz miktar veya trade kapalı)")
        }
    }
}

// MARK: - Trade Brain Alert Model

struct TradeBrainAlert: Identifiable, Equatable {
    let id = UUID()
    let timestamp = Date()
    let type: AlertType
    let symbol: String
    let message: String
    let actionDescription: String
    let priority: AlertPriority
    
    enum AlertType: String {
        case planTriggered = "PLAN"
        case targetReached = "HEDEF"
        case stopApproaching = "STOP_YAKIN"
        case councilChanged = "KONSEY"
    }
    
    enum AlertPriority: String {
        case low = "DÜŞÜK"
        case medium = "ORTA"
        case high = "YÜKSEK"
        case critical = "KRİTİK"
    }
    
    static func == (lhs: TradeBrainAlert, rhs: TradeBrainAlert) -> Bool {
        lhs.id == rhs.id
    }
}
