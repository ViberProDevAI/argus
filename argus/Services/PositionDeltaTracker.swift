import Foundation

// MARK: - Position Delta Tracker
/// Entry Snapshot ile şu anki durumu karşılaştırarak değişimleri takip eder

class PositionDeltaTracker {
    static let shared = PositionDeltaTracker()
    
    private init() {}
    
    // MARK: - Delta Calculation
    
    struct PositionDelta {
        let tradeId: UUID
        let symbol: String
        let calculatedAt: Date
        
        // Fiyat Değişimi
        let priceChange: Double         // +4.7%
        let pnlPercent: Double          // Toplam kâr/zarar %
        
        // Skor Değişimleri
        let orionDelta: Double          // -16 puan
        let orionNow: Double
        let orionEntry: Double
        
        // Council Değişimi
        let councilActionChanged: Bool
        let councilActionEntry: ArgusAction
        let councilActionNow: ArgusAction?
        let confidenceChange: Double    // -0.15
        
        // Aether Değişimi
        let aetherStanceChanged: Bool
        let aetherStanceEntry: MacroStance
        let aetherStanceNow: MacroStance?
        
        // Teknik Değişimler
        let rsiEntry: Double?
        let rsiNow: Double?
        let rsiChange: Double?
        let trendReversed: Bool         // Yükseliş→düşüş veya tersi
        
        // Makro Değişimler
        let vixEntry: Double?
        let vixNow: Double?
        let vixChange: Double?
        let spyChange: Double?          // SPY % değişimi
        
        // Temel Değişimler
        let newEarningsReleased: Bool
        let daysHeld: Int
        
        // MARK: - Significance Assessment
        
        var significance: ChangeSignificance {
            // Kritik: Yeni bilanço açıklandı
            if newEarningsReleased { return .critical }
            
            // Yüksek: Council aksiyonu değişti ve güven düştü
            if councilActionChanged {
                let wasPositive = [.aggressiveBuy, .accumulate].contains(councilActionEntry)
                let nowNegative = councilActionNow == .trim || councilActionNow == .liquidate
                if wasPositive && nowNegative { return .critical }
                if abs(confidenceChange) > 0.3 { return .high }
                return .medium
            }
            
            // Orta: Orion skoru önemli ölçüde düştü
            if orionDelta < -20 { return .high }
            if orionDelta < -10 { return .medium }
            
            // Orta: VIX çok yükseldi
            if let vixNow = vixNow, vixNow > 30 { return .medium }
            
            // Orta: Aether stance değişti (riskten kaçınmaya)
            if aetherStanceChanged && aetherStanceNow == .defensive { return .medium }
            
            // Düşük: Küçük değişiklikler
            return .low
        }
        
        var significanceEmoji: String {
            switch significance {
            case .critical: return "🚨"
            case .high: return "⚠️"
            case .medium: return "📊"
            case .low: return "✓"
            }
        }
        
        var summaryText: String {
            var parts: [String] = []
            
            // Orion değişimi
            if abs(orionDelta) >= 5 {
                let direction = orionDelta > 0 ? "↑" : "↓"
                parts.append("Orion \(direction)\(Int(abs(orionDelta)))")
            }
            
            // Council değişimi
            if councilActionChanged {
                parts.append("Karar: \(councilActionEntry.rawValue)→\(councilActionNow?.rawValue ?? "?")")
            }
            
            // Aether değişimi
            if aetherStanceChanged {
                parts.append("Aether değişti")
            }
            
            // VIX değişimi
            if let change = vixChange, abs(change) > 5 {
                let direction = change > 0 ? "↑" : "↓"
                parts.append("VIX \(direction)")
            }
            
            if parts.isEmpty {
                return "Değişiklik yok"
            }
            
            return parts.joined(separator: " | ")
        }
        
        // MARK: - Recommendations
        
        var recommendations: [DeltaRecommendation] {
            var recs: [DeltaRecommendation] = []
            
            // Kritik: Council negatife döndü
            if councilActionChanged {
                let wasPositive = [.aggressiveBuy, .accumulate].contains(councilActionEntry)
                let nowNegative = councilActionNow == .trim || councilActionNow == .liquidate
                
                if wasPositive && nowNegative {
                    if newEarningsReleased {
                        recs.append(.init(
                            priority: .critical,
                            action: "Pozisyonu gözden geçir",
                            reason: "Bilanço sonrası Council negatife döndü"
                        ))
                    } else {
                        recs.append(.init(
                            priority: .high,
                            action: "Kısmi satış düşün",
                            reason: "Council \(councilActionEntry.rawValue) → \(councilActionNow?.rawValue ?? "?"), ama bilanço değişmedi - teknik gürültü olabilir"
                        ))
                    }
                }
            }
            
            // Orion düşüşü
            if orionDelta < -15 {
                recs.append(.init(
                    priority: .medium,
                    action: "Teknik durumu kontrol et",
                    reason: "Orion \(Int(orionDelta)) puan düştü"
                ))
            }
            
            // VIX yükselişi
            if let vixNow = vixNow, vixNow > 25 {
                recs.append(.init(
                    priority: .medium,
                    action: "Stop seviyelerini kontrol et",
                    reason: "VIX yüksek (\(Int(vixNow))), volatilite arttı"
                ))
            }
            
            // Uzun süre tutma
            if daysHeld > 60 && pnlPercent < 5 {
                recs.append(.init(
                    priority: .low,
                    action: "Pozisyonu yeniden değerlendir",
                    reason: "\(daysHeld) gün oldu, yeterli getiri yok (%\(String(format: "%.1f", pnlPercent)))"
                ))
            }
            
            return recs
        }
    }
    
    struct DeltaRecommendation {
        let priority: ChangeSignificance
        let action: String
        let reason: String
    }
    
    enum ChangeSignificance: String, Codable {
        case low = "DÜŞÜK"          // Gürültü, planı değiştirme
        case medium = "ORTA"        // Dikkat et, izle
        case high = "YÜKSEK"        // Plan revizyonu düşün
        case critical = "KRİTİK"    // Acil aksiyon gerekebilir
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    // MARK: - Calculate Delta
    
    func calculateDelta(
        for trade: Trade,
        entrySnapshot: EntrySnapshot,
        currentOrionScore: Double,
        currentGrandDecision: ArgusGrandDecision?,
        currentPrice: Double,
        currentRSI: Double? = nil,
        currentVIX: Double? = nil,
        currentSPY: Double? = nil
    ) -> PositionDelta {
        
        let pnlPercent = ((currentPrice - entrySnapshot.entryPrice) / entrySnapshot.entryPrice) * 100
        let priceChange = ((currentPrice - entrySnapshot.entryPrice) / entrySnapshot.entryPrice) * 100
        
        let orionDelta = currentOrionScore - entrySnapshot.orionScore
        
        let councilChanged = currentGrandDecision?.action != entrySnapshot.councilAction
        let confidenceChange = (currentGrandDecision?.confidence ?? 0) - entrySnapshot.councilConfidence
        
        let aetherChanged = currentGrandDecision?.aetherDecision.stance != entrySnapshot.aetherStance
        
        var rsiChange: Double? = nil
        if let entryRSI = entrySnapshot.rsi, let nowRSI = currentRSI {
            rsiChange = nowRSI - entryRSI
        }
        
        var vixChange: Double? = nil
        if let entryVIX = entrySnapshot.vix, let nowVIX = currentVIX {
            vixChange = nowVIX - entryVIX
        }
        
        var spyChange: Double? = nil
        if let entrySPY = entrySnapshot.spyPrice, let nowSPY = currentSPY {
            spyChange = ((nowSPY - entrySPY) / entrySPY) * 100
        }
        
        let daysHeld = Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
        
        // Yeni bilanço kontrolü
        let newEarnings = checkNewEarnings(symbol: trade.symbol, since: entrySnapshot.capturedAt)
        
        return PositionDelta(
            tradeId: trade.id,
            symbol: trade.symbol,
            calculatedAt: Date(),
            priceChange: priceChange,
            pnlPercent: pnlPercent,
            orionDelta: orionDelta,
            orionNow: currentOrionScore,
            orionEntry: entrySnapshot.orionScore,
            councilActionChanged: councilChanged,
            councilActionEntry: entrySnapshot.councilAction,
            councilActionNow: currentGrandDecision?.action,
            confidenceChange: confidenceChange,
            aetherStanceChanged: aetherChanged,
            aetherStanceEntry: entrySnapshot.aetherStance,
            aetherStanceNow: currentGrandDecision?.aetherDecision.stance,
            rsiEntry: entrySnapshot.rsi,
            rsiNow: currentRSI,
            rsiChange: rsiChange,
            trendReversed: false, // TODO: Trend analizi
            vixEntry: entrySnapshot.vix,
            vixNow: currentVIX,
            vixChange: vixChange,
            spyChange: spyChange,
            newEarningsReleased: newEarnings,
            daysHeld: daysHeld
        )
    }
    
    private func checkNewEarnings(symbol: String, since: Date) -> Bool {
        // EventCalendar'dan kontrol edilebilir
        // Şimdilik false
        return false
    }
    
    // MARK: - Debug
    
    func printDeltaSummary(_ delta: PositionDelta) {
        print("═══════════════════════════════════════")
        print("📊 DELTA ANALİZİ: \(delta.symbol)")
        print("═══════════════════════════════════════")
        print("Fiyat: \(delta.pnlPercent > 0 ? "+" : "")\(String(format: "%.1f", delta.pnlPercent))%")
        print("Orion: \(Int(delta.orionEntry)) → \(Int(delta.orionNow)) (\(delta.orionDelta > 0 ? "+" : "")\(Int(delta.orionDelta)))")
        
        if delta.councilActionChanged {
            print("Council: \(delta.councilActionEntry.rawValue) → \(delta.councilActionNow?.rawValue ?? "?")")
        }
        
        if delta.aetherStanceChanged {
            print("Aether: Değişti!")
        }
        
        print("───────────────────────────────────────")
        print("\(delta.significanceEmoji) Önem: \(delta.significance.rawValue)")
        print("───────────────────────────────────────")
        
        for rec in delta.recommendations {
            print("💡 [\(rec.priority.rawValue)] \(rec.action)")
            print("   \(rec.reason)")
        }
        print("═══════════════════════════════════════")
    }
}
