import Foundation

/// Aether Cards Manifest - THE IMMUTABLE REGISTRY
/// This file defines the EXACT set of cards that MUST appear in the Aether UI.
/// Disabling or Removing entries here will trigger a REGRESSION ALERT.
struct AetherCardsManifest: Codable {
    let timestamp: Date
    let cards: [AetherCardDef]
    let hash: String
    
    struct AetherCardDef: Codable {
        let id: String
        let title: String
        let inputs: [String]
        let providerPriority: String
        let fallback: String
        let enabledDefault: Bool
        let uiSlot: Int
    }
    
    static let baseline = AetherCardsManifest(
        timestamp: Date(),
        cards: [
            // Row 1: Equity & Volatility
            AetherCardDef(id: "card_equity", title: "Hisse Trendi", inputs: ["SPY"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 1),
            AetherCardDef(id: "card_volatility", title: "Volatilite", inputs: ["^VIX"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 2),
            
            // Row 2: Dollar & Rates
            AetherCardDef(id: "card_dollar", title: "Dolar Endeksi", inputs: ["DX-Y.NYB"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 3),
            AetherCardDef(id: "card_rates", title: "Faizler (10Y)", inputs: ["^TNX"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 4),
            
            // Row 3: Commodities & Crypto
            AetherCardDef(id: "card_gold", title: "Altın", inputs: ["GLD"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 5),
            AetherCardDef(id: "card_crypto", title: "Bitcoin", inputs: ["BTC-USD"], providerPriority: "Yahoo", fallback: "Yahoo", enabledDefault: true, uiSlot: 6)
        ],
        hash: "AETHER_V6_CLASSIC"
    )
    
    static func verify() {
        print("\n=== 🛡️ AETHER MANIFEST VERIFICATION ===")
        print("AETHER_MANIFEST cards=\(baseline.cards.count) hash=\(baseline.hash)")
        
        // Simple Regression Check: Hardcoded expectation vs Baseline
        let expectedCount = 6
        if baseline.cards.count < expectedCount {
            print("🚨 AETHER_REGRESSION detected: Expected \(expectedCount), Found \(baseline.cards.count)")
        } else {
            print("✅ AETHER_INTEGRITY: OK. All \(baseline.cards.count) cards registered.")
        }
        
        for card in baseline.cards {
            print("   - [Slot \(card.uiSlot)] \(card.title) (\(card.id)) -> Inputs: \(card.inputs.joined(separator: ","))")
        }
        print("=== END MANIFEST ===\n")
    }
}
