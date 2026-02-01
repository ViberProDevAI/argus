import Foundation
import SwiftUI

/// REJİM: Birleşik Makro/Piyasa Modü
/// Sirkiye (Makro) + Oracle (Sinyalleri) + Sektör Rotasyonu

// MARK: - Types

enum SymbolType {
    case bist
    case global
}

enum RejimSignal: String, Sendable {
    case riskOn = "RISK-ON"
    case riskOff = "RISK-OFF"
    case neutral = "NEUTRAL"
    
    var color: String {
        switch self {
        case .riskOn: return "green"
        case .neutral: return "yellow"
        case .riskOff: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .riskOn: return "arrow.up.circle.fill"
        case .neutral: return "pause.circle"
        case .riskOff: return "arrow.down.circle.fill"
        }
    }
}

struct RejimResult: Sendable {
    let symbol: String
    let signal: RejimSignal
    let confidence: Double
    let sirkiyeScore: Double
    let oracleScore: Double
    let sectorScore: Double
    let macroRegime: MacroRegime
    let summary: String
    let timestamp: Date
    
    enum MacroRegime: String, Sendable {
        case expansion = "EXPANSION"
        case peak = "PEAK"
        case recession = "RECESSION"
        case contraction = "CONTRACTION"
        case recovery = "RECOVERY"
        
        var color: Color {
            switch self {
            case .expansion: return .green
            case .peak: return .orange
            case .recession: return .red
            case .contraction: return .purple
            case .recovery: return .mint
            }
        }
        
        var description: String {
            switch self {
            case .expansion: return "Büyüme fazı"
            case .peak: return "zirve noktası"
            case .recession: return "düşüş fazı"
            case .contraction: return "daralma"
            case .recovery: return "toparlanma"
            }
        }
    }
}

// MARK: - Main Engine

actor RejimEngine {
    static let shared = RejimEngine()
    private init() {}
    
    // MARK: - Main Analysis
    
    func analyze(symbol: String) async throws -> RejimResult {
        let cleanSymbol = symbol.uppercased()
        
        // MARK: - Symbol Type Detection
        let symbolType: SymbolType
        if cleanSymbol.hasSuffix(".IS") || cleanSymbol.hasSuffix("-IS") {
            symbolType = .bist
        } else {
            symbolType = .global
        }
        
        // MARK: - Sirkiye Makro (sadece BIST için)
        var sirkiyeScore: Double = 50.0
        
        if symbolType == .bist {
            do {
                let input = SirkiyeEngine.SirkiyeInput(
                    usdTry: await getUSDTry(),
                    usdTryPrevious: await getUSDTryPrevious(),
                    dxy: await getDXY(),
                    brentOil: await getBrentOil(),
                    globalVix: await getGlobalVIX(),
                    newsSnapshot: await getNewsSnapshot(symbol: cleanSymbol)
                )
                let sirkiyeResult = try await SirkiyeEngine.shared.analyze(input: input)
                sirkiyeScore = sirkiyeResult.netSupport * 100.0
            } catch {
                print("⚠️ RejimEngine: Sirkiye analizi başarısız: \(error)")
            }
        }
        
        // MARK: - Oracle Sinyalleri (sadece Global için)
        var oracleScore: Double = 50.0
        
        if symbolType == .global {
            do {
                let signals = try await OracleEngine.shared.getSignals(for: cleanSymbol)
                let buySignals = signals.filter { $0.sentiment == .bullish }
                let sellSignals = signals.filter { $0.sentiment == .bearish }
                
                if buySignals.count > sellSignals.count * 2 {
                    oracleScore = 80.0 // Strong buy
                } else if buySignals.count > sellSignals.count {
                    oracleScore = 60.0 // Buy
                } else if sellSignals.count > buySignals.count * 2 {
                    oracleScore = 35.0 // Strong sell
                } else if sellSignals.count > buySignals.count {
                    oracleScore = 50.0 // Neutral
                } else {
                    oracleScore = 50.0
                }
            } catch {
                print("⚠️ RejimEngine: Oracle analizi başarısız: \(error)")
            }
        }
        
        // MARK: - Sektör Rotasyonu
        var sectorScore: Double = 50.0
        
        if symbolType == .bist {
            do {
                let sectorResult = try await BistSektorEngine.shared.analyze(symbol: cleanSymbol)
                sectorScore = sectorResult.score
            } catch {
                print("⚠️ RejimEngine: Sektör analizi başarısız: \(error)")
            }
        }
        
        // MARK: - Makro Regime Tespiti
        let regime = detectMacroRegime(
            sirkiyeScore: sirkiyeScore,
            oracleScore: oracleScore,
            sectorScore: sectorScore
        )
        
        // MARK: - Birleşik Skor
        let totalScore = (sirkiyeScore * 0.4) + (oracleScore * 0.35) + (sectorScore * 0.25)
        
        // MARK: - Sinyal Belirleme
        let signal: RejimSignal
        if totalScore >= 70 {
            signal = .riskOn
        } else if totalScore <= 30 {
            signal = .riskOff
        } else {
            signal = .neutral
        }
        
        // MARK: - Özet
        let summary = generateSummary(
            symbolType: symbolType,
            sirkiyeScore: sirkiyeScore,
            oracleScore: oracleScore,
            sectorScore: sectorScore,
            totalScore: totalScore,
            regime: regime
        )
        
        return RejimResult(
            symbol: cleanSymbol,
            signal: signal,
            confidence: totalScore,
            sirkiyeScore: sirkiyeScore,
            oracleScore: oracleScore,
            sectorScore: sectorScore,
            macroRegime: regime,
            summary: summary,
            timestamp: Date()
        )
    }
    
    // MARK: - Makro Regime Detection
    
    private func detectMacroRegime(
        sirkiyeScore: Double,
        oracleScore: Double,
        sectorScore: Double
    ) -> RejimResult.MacroRegime {
        let marketScore = sirkiyeScore * 0.4 + oracleScore * 0.35
        let leadingScore = sectorScore * 0.25
        
        if sirkiyeScore >= 70 && oracleScore >= 70 {
            return .expansion
        } else if sirkiyeScore <= 30 || oracleScore <= 30 {
            return .recession
        } else if marketScore >= 70 && leadingScore >= 70 {
            return .peak
        } else if sirkiyeScore < 50 {
            return .contraction
        } else {
            return .recovery
        }
    }
    
    // MARK: - Özet Oluşturma
    
    private func generateSummary(
        symbolType: SymbolType,
        sirkiyeScore: Double,
        oracleScore: Double,
        sectorScore: Double,
        totalScore: Double,
        regime: RejimResult.MacroRegime
    ) -> String {
        var parts = [String]()
        
        if symbolType == .bist {
            parts.append("BIST Analizi:")
        } else {
            parts.append("Global Analizi:")
        }
        
        // Sirkiye durumu
        if sirkiyeScore >= 70 {
            parts.append("Makro riskleri nötr.")
        } else if sirkiyeScore <= 30 {
            parts.append("Makro riskleri yüksek.")
        }
        
        // Oracle durumu
        if oracleScore >= 70 {
            parts.append("Oracle sinyalleri pozitif.")
        } else if oracleScore <= 30 {
            parts.append("Oracle sinyalleri negatif.")
        }
        
        // Sektör durumu
        if sectorScore >= 70 {
            parts.append("Sektör performansı güçlü.")
        } else if sectorScore <= 30 {
            parts.append("Sektör performansı zayıf.")
        }
        
        // Makro rejimi
        parts.append("Makro rejimi: \(regime.description)")
        
        return parts.joined(separator: " | ")
    }
    
    // MARK: - Helper Functions
    
    private func getUSDTry() async -> Double {
        do {
            let quote = try await HeimdallOrchestrator.shared.requestQuote(symbol: "USD/TRY")
            return quote.currentPrice
        } catch {
            return 35.0
        }
    }
    
    private func getUSDTryPrevious() async -> Double {
        return 35.0  // TODO: Implement cache
    }
    
    private func getDXY() async -> Double {
        // TODO: Implement Heimdall or external API
        return 104.0
    }
    
    private func getBrentOil() async -> Double? {
        // TODO: Implement Heimdall or external API
        return nil
    }
    
    private func getGlobalVIX() async -> Double? {
        // TODO: Implement Heimdall or external API
        return nil
    }
    
    private func getNewsSnapshot(symbol: String) async -> HermesNewsSnapshot? {
        if let payload = try? await BISTSentimentEngine.shared.analyzeSentimentPayload(for: symbol) {
            return BISTSentimentAdapter.adapt(result: payload.result, articles: payload.articles)
        }
        return nil
    }
}
