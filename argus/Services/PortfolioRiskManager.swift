import Foundation

// MARK: - Portfolio Risk Manager
/// Portföy seviyesi risk kontrolü ve limitler

class PortfolioRiskManager {
    static let shared = PortfolioRiskManager()
    
    // MARK: - Risk Limitleri (Configurable)
    
    struct RiskLimits {
        // Nakit Limitleri
        var minCashRatio: Double = 0.20          // Minimum %20 nakit tut
        var emergencyCashRatio: Double = 0.10    // Acil durum nakit eşiği
        
        // Pozisyon Limitleri
        var maxOpenPositions: Int = 15           // Maksimum açık pozisyon
        var maxPositionWeight: Double = 0.15     // Tek pozisyon maksimum %15
        var minPositionSize: Double = 1000       // Minimum pozisyon TL
        
        // Sektör Limitleri
        var maxSectorConcentration: Double = 0.40 // Tek sektörde maksimum %40
        var maxSectorPositions: Int = 5          // Tek sektörde maksimum 5 hisse
        
        // Risk Limitleri
        var maxPortfolioDrawdown: Double = 0.15  // Maksimum %15 drawdown
        var maxDailyLoss: Double = 0.03          // Günlük maksimum %3 kayıp
        
        // AutoPilot Limitleri
        var maxDailyTrades: Int = 10             // Günlük maksimum işlem
        var cooldownBetweenTrades: TimeInterval = 300 // 5 dakika bekleme
    }
    
    var limits = RiskLimits()
    /// Sınırsız Mod: Pozisyon limitlerini bypass eder
    var isUnlimitedPositionsEnabled: Bool = false
    
    private var dailyTradeCount: Int = 0
    private var lastTradeTime: Date?
    private var lastResetDate: Date = Date()
    
    private init() {
        resetDailyCountIfNeeded()
    }
    
    // MARK: - Pre-Trade Risk Check
    
    struct RiskCheckResult {
        let canTrade: Bool
        let warnings: [String]
        let blockers: [String]
        let adjustedQuantity: Double?
        let reason: String
    }
    
    /// Alım öncesi risk kontrolü
    func checkBuyRisk(
        symbol: String,
        proposedAmount: Double,
        currentPrice: Double,
        portfolio: [Trade],
        cashBalance: Double,
        totalEquity: Double
    ) -> RiskCheckResult {
        
        var warnings: [String] = []
        var blockers: [String] = []
        var adjustedAmount = proposedAmount
        
        resetDailyCountIfNeeded()
        
        // 1. Nakit Oranı Kontrolü
        let currentCashRatio = cashBalance / totalEquity
        let afterTradeCash = cashBalance - proposedAmount
        let afterTradeCashRatio = afterTradeCash / totalEquity
        
        if afterTradeCashRatio < limits.emergencyCashRatio {
            blockers.append("Acil durum nakit eşiği! Nakit oranı %\(Int(limits.emergencyCashRatio * 100))'ün altına düşemez")
            return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Nakit yetersiz")
        }
        
        if afterTradeCashRatio < limits.minCashRatio {
            let maxAllowedAmount = cashBalance - (totalEquity * limits.minCashRatio)
            if maxAllowedAmount > 0 {
                adjustedAmount = min(proposedAmount, maxAllowedAmount)
                warnings.append("Nakit oranı uyarısı: Miktar \(formatCurrency(adjustedAmount))'ye düşürüldü")
            } else {
                blockers.append("Minimum nakit oranı aşılacak (%\(Int(limits.minCashRatio * 100)))")
                return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Nakit limiti")
            }
        }
        
        // 2. Maksimum Pozisyon Sayısı
        let openPositions = portfolio.filter { $0.isOpen }
        let existingPosition = openPositions.first { $0.symbol == symbol }
        
        // Sınırsız mod açıksa veya limit aşılmadıysa
        if !isUnlimitedPositionsEnabled {
            if existingPosition == nil && openPositions.count >= limits.maxOpenPositions {
                blockers.append("Maksimum pozisyon sayısı aşıldı (\(limits.maxOpenPositions))")
                return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Pozisyon limiti")
            }
        } else {
            if existingPosition == nil && openPositions.count >= limits.maxOpenPositions {
                warnings.append("⚠️ Pozisyon limiti (\(limits.maxOpenPositions)) aşıldı fakat 'Sınırsız Mod' aktif.")
            }
        }
        
        if openPositions.count >= limits.maxOpenPositions - 2 {
            warnings.append("Pozisyon limiti yaklaşıyor: \(openPositions.count)/\(limits.maxOpenPositions)")
        }
        
        // 3. Tek Pozisyon Ağırlık Kontrolü
        let proposedWeight = adjustedAmount / totalEquity
        if proposedWeight > limits.maxPositionWeight {
            let maxAmount = totalEquity * limits.maxPositionWeight
            adjustedAmount = min(adjustedAmount, maxAmount)
            warnings.append("Tek pozisyon ağırlığı %\(Int(limits.maxPositionWeight * 100)) ile sınırlandı")
        }
        
        // Mevcut pozisyon varsa toplam ağırlığı kontrol et
        if let existing = existingPosition {
            let existingValue = existing.quantity * currentPrice
            let totalPositionValue = existingValue + adjustedAmount
            let totalWeight = totalPositionValue / totalEquity
            
            if totalWeight > limits.maxPositionWeight {
                let maxAddition = (totalEquity * limits.maxPositionWeight) - existingValue
                if maxAddition <= 0 {
                    blockers.append("Bu pozisyon zaten maksimum ağırlıkta")
                    return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Ağırlık limiti")
                }
                adjustedAmount = min(adjustedAmount, maxAddition)
                warnings.append("Ek alım sınırlandı: Pozisyon ağırlığı %\(Int(limits.maxPositionWeight * 100))'de")
            }
        }
        
        // 4. Minimum Pozisyon Boyutu
        if adjustedAmount < limits.minPositionSize {
            blockers.append("Minimum pozisyon boyutu: \(formatCurrency(limits.minPositionSize))")
            return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Minimum boyut")
        }
        
        // 5. Günlük İşlem Limiti
        if dailyTradeCount >= limits.maxDailyTrades {
            blockers.append("Günlük işlem limiti aşıldı (\(limits.maxDailyTrades))")
            return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Günlük limit")
        }
        
        // 6. İşlemler Arası Bekleme
        if let lastTime = lastTradeTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < limits.cooldownBetweenTrades {
                let remaining = Int(limits.cooldownBetweenTrades - elapsed)
                blockers.append("İşlemler arası bekleme: \(remaining) saniye")
                return RiskCheckResult(canTrade: false, warnings: warnings, blockers: blockers, adjustedQuantity: nil, reason: "Cooldown")
            }
        }
        
        // Tüm kontroller geçti
        let wasAdjusted = adjustedAmount != proposedAmount
        let finalQuantity = adjustedAmount / currentPrice
        
        return RiskCheckResult(
            canTrade: true,
            warnings: warnings,
            blockers: blockers,
            adjustedQuantity: wasAdjusted ? finalQuantity : nil,
            reason: warnings.isEmpty ? "Tüm kontroller geçti" : "Uyarılarla onaylandı"
        )
    }
    
    // MARK: - Trade Completed
    
    func recordTrade() {
        dailyTradeCount += 1
        lastTradeTime = Date()
    }
    
    // MARK: - Portfolio Health Check
    
    struct PortfolioHealth {
        let score: Double           // 0-100
        let status: HealthStatus
        let issues: [String]
        let suggestions: [String]
        // FAZE 3.1: Risk-Adjusted Return
        let riskAdjustedReturn: Double  // PnL / Risk (Sharpe Ratio-like)
    }
    
    enum HealthStatus: String {
        case healthy = "SAĞLIKLI"
        case warning = "UYARI"
        case critical = "KRİTİK"
    }
    
    func checkPortfolioHealth(
        portfolio: [Trade],
        cashBalance: Double,
        totalEquity: Double,
        quotes: [String: Quote]
    ) -> PortfolioHealth {
        
        var score: Double = 100
        var issues: [String] = []
        var suggestions: [String] = []
        
        let openPositions = portfolio.filter { $0.isOpen }
        
        // 1. Nakit Oranı
        let cashRatio = cashBalance / totalEquity
        if cashRatio < limits.emergencyCashRatio {
            score -= 30
            issues.append("Nakit oranı kritik: %\(Int(cashRatio * 100))")
            suggestions.append("Bazı pozisyonları azaltarak nakit oranını artırın")
        } else if cashRatio < limits.minCashRatio {
            score -= 15
            issues.append("Nakit oranı düşük: %\(Int(cashRatio * 100))")
        }
        
        // 2. Pozisyon Sayısı
        if openPositions.count > limits.maxOpenPositions {
            score -= 20
            issues.append("Pozisyon sayısı fazla: \(openPositions.count)")
        }
        
        // 3. Konsantrasyon
        var positionWeights: [(String, Double)] = []
        for trade in openPositions {
            let price = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let value = trade.quantity * price
            let weight = value / totalEquity
            positionWeights.append((trade.symbol, weight))
            
            if weight > limits.maxPositionWeight {
                score -= 10
                issues.append("\(trade.symbol) ağırlığı fazla: %\(Int(weight * 100))")
            }
        }
        
        // 4. Toplam Risk (Unrealized PnL)
        var totalUnrealizedPnL: Double = 0
        var totalRisk: Double = 0  // FAZE 3.1: Risk-adjusted return için
        
        for trade in openPositions {
            let price = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let pnl = (price - trade.entryPrice) * trade.quantity
            totalUnrealizedPnL += pnl
            
            // FAZE 3.1: Risk hesapla (basit ATR varsayımı)
            // Gerçek implementasyon için ATR data'ya ihtiyaç var
            let atr = price * 0.02  // Varsayılan %2 günlük volatilite
            let positionRisk = atr * trade.quantity
            totalRisk += positionRisk
        }
        
        let unrealizedPnLRatio = totalUnrealizedPnL / totalEquity
        
        // FAZE 3.1: Risk-Adjusted Return hesapla
        let riskAdjustedReturn: Double
        if totalRisk > 0 {
            riskAdjustedReturn = totalUnrealizedPnL / totalRisk
        } else {
            riskAdjustedReturn = 0
        }
        if unrealizedPnLRatio < -limits.maxPortfolioDrawdown {
            score -= 30
            issues.append("Portföy drawdown kritik: %\(String(format: "%.1f", unrealizedPnLRatio * 100))")
            suggestions.append("Zarar eden pozisyonları gözden geçirin")
        }
        
        // Status belirleme
        let status: HealthStatus
        if score >= 80 {
            status = .healthy
        } else if score >= 50 {
            status = .warning
        } else {
            status = .critical
        }
        
        return PortfolioHealth(
            score: max(0, score),
            status: status,
            issues: issues,
            suggestions: suggestions,
            riskAdjustedReturn: riskAdjustedReturn
        )
    }
    
    // MARK: - Helpers
    
    // FAZE 3.2: Position Sizing Algorithm (Kelly Criterion)
    
    /// Optimal pozisyon boyutunu hesapla (Kelly Criterion)
    /// Win Rate, Win/Loss ratio, Sharpe gibi metrikler kullanılır
    func calculateOptimalPositionSize(
        symbol: String,
        currentPrice: Double,
        winRate: Double,      // 0-100
        avgWin: Double,        // Ortalama kazanç
        avgLoss: Double,       // Ortalama kayıp
        totalEquity: Double,
        maxRiskPercent: Double = 0.25  // Max %25 of equity (conservative Kelly)
    ) -> (optimalQuantity: Double, kellyPercent: Double, explanation: String) {
        
        // 1. Kelly Criterion hesapla
        // Kelly% = (Win% * (AvgWin / AvgLoss) - Loss%) / (AvgWin / AvgLoss)
        
        let winPercent = winRate / 100.0
        let lossPercent = 1.0 - winPercent
        
        guard avgLoss > 0 else {
            return (
                optimalQuantity: 0,
                kellyPercent: 0,
                explanation: "Hata: AvgLoss 0'dan büyük olmalı"
            )
        }
        
        let winLossRatio = avgWin / avgLoss
        let kellyRaw = (winPercent * winLossRatio) - lossPercent
        let kellyPercent = max(0, min(maxRiskPercent, kellyRaw))
        
        // 2. Optimal miktar
        let optimalAmount = totalEquity * kellyPercent
        // currentPrice parametre olarak geliyor
        
        guard currentPrice > 0 else {
            return (
                optimalQuantity: 0,
                kellyPercent: 0,
                explanation: "Hata: Mevcut fiyat bulunamadı"
            )
        }
        
        let optimalQuantity = optimalAmount / currentPrice
        
        // 3. Açıklama
        let explanation = String(
            format: "Kelly: %.1f%% | Win Rate: %.0f%% | W/L: %.2f | Optimal: %.0f TL",
            kellyPercent * 100,
            winRate,
            winLossRatio,
            optimalAmount
        )
        
        return (optimalQuantity, kellyPercent, explanation)
    }
    
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyTradeCount = 0
            lastResetDate = Date()
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        return String(format: "%.0f TL", value)
    }
    
    // MARK: - Debug
    
    func printRiskSummary(portfolio: [Trade], cashBalance: Double, totalEquity: Double) {
        print("═══════════════════════════════════════")
        print("📊 PORTFÖY RİSK ÖZETİ")
        print("═══════════════════════════════════════")
        print("Toplam Değer: \(formatCurrency(totalEquity))")
        print("Nakit: \(formatCurrency(cashBalance)) (%\(Int((cashBalance/totalEquity) * 100)))")
        print("Açık Pozisyon: \(portfolio.filter { $0.isOpen }.count)/\(limits.maxOpenPositions)")
        print("Günlük İşlem: \(dailyTradeCount)/\(limits.maxDailyTrades)")
        print("═══════════════════════════════════════")
    }
}
