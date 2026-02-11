import Foundation

/// Smart Plan üretimi ve Grand Decision yönetimini üstlenen servis.
/// TradingViewModel'in yükünü hafifletir.
class SmartPlanService {
    static let shared = SmartPlanService()
    
    private init() {}
    
    /// Bir işlem (Trade) için Smart Plan oluşturur
    /// Mevcut verileri (fiyat, sinyal vs) kullanarak planı ve senaryoları hazırlar.
    func createPlan(
        for trade: Trade,
        quotes: [String: Quote],
        grandDecisions: [String: ArgusGrandDecision]
    ) async -> PositionPlan {
        
        let symbol = trade.symbol
        
        // 1. Grand Decision Al (Yoksa Nötr oluştur)
        let decision = grandDecisions[symbol] ?? createNeutralDecision(for: symbol)
        
        // 2. Snapshot Oluştur
        let snapshot = EntrySnapshot(
            tradeId: trade.id,
            symbol: symbol,
            entryPrice: trade.entryPrice,
            grandDecision: decision,
            orionScore: 50.0, // Varsayılan, gerekirse OrionStore'dan çekilebilir
            atlasScore: nil,
            technicalData: nil,
            macroData: nil,
            fundamentalData: nil
        )
        
        // 3. Adaptive Plan Üret (SmartPlanGenerator kullanarak)
        let result = SmartPlanGenerator.shared.generateAdaptivePlan(
            entryPrice: trade.entryPrice,
            entrySnapshot: snapshot,
            grandDecision: decision
        )
        
        // 4. Sonuç Planı Oluştur
        let plan = PositionPlan(
            tradeId: trade.id,
            snapshot: snapshot,
            initialQuantity: trade.quantity,
            thesis: result.reason,
            invalidation: "Stop loss seviyesi ihlali",
            bullish: result.scenarios.first(where: { $0.type == .bullish }) ?? result.scenarios[0],
            bearish: result.scenarios.first(where: { $0.type == .bearish }) ?? result.scenarios[0],
            neutral: result.scenarios.first(where: { $0.type == .neutral }),
            intent: .momentumTrade
        )
        
        return plan
    }
    
    // Helper to create dummy decision
    private func createNeutralDecision(for symbol: String) -> ArgusGrandDecision {
        let orionDummy = CouncilDecision(
            symbol: symbol, action: .hold, netSupport: 0, approveWeight: 0,
            vetoWeight: 0, isStrongSignal: false, isWeakSignal: false,
            winningProposal: nil, allProposals: [], votes: [], vetoReasons: [], timestamp: Date()
        )
        
        let aetherDummy = AetherDecision(
            stance: .cautious, marketMode: .neutral, netSupport: 0,
            isStrongSignal: false, winningProposal: nil, votes: [], warnings: [], timestamp: Date()
        )
        
        return ArgusGrandDecision(
            id: UUID(),
            symbol: symbol,
            action: .neutral,
            strength: .normal,
            confidence: 0.5,
            reasoning: "Otomatik Nötr (Veri Yok)",
            contributors: [],
            vetoes: [],
            orionDecision: orionDummy,
            atlasDecision: nil,
            aetherDecision: aetherDummy,
            hermesDecision: nil,
            orionDetails: nil,
            financialDetails: nil,
            bistDetails: nil,
            patterns: nil,
            timestamp: Date()
        )
    }
}
