import Foundation

// MARK: - BIST Cash Flow Engine
// Şirketin nakit üretme gücünü analiz eder
// "Cash is King" prensibi
// Puan: 0-100

actor BistCashFlowEngine {
    static let shared = BistCashFlowEngine()
    
    private init() {}
    
    struct CashFlowResult: Sendable {
        let score: Double
        let status: CashFlowStatus
        let details: String
    }
    
    enum CashFlowStatus: String, Sendable {
        case machine = "Nakit Makinesi" // OCF/NetIncome > 1.2
        case strong = "Güçlü Nakit" // OCF/NetIncome > 1.0
        case adequate = "Yeterli" // OCF/NetIncome > 0.8
        case weak = "Zayıf" // OCF/NetIncome < 0.8 veya Negatif
        case burner = "Nakit Yakıyor" // Negatif OCF
        case unknown = "Veri Yok"
        
        var color: String {
            switch self {
            case .machine: return "purple"
            case .strong: return "green"
            case .adequate: return "yellow"
            case .weak: return "orange"
            case .burner: return "red"
            case .unknown: return "gray"
            }
        }
    }
    
    /// BIST Financials verisinden nakit akışı analizi yapar
    func analyze(financials: BistFinancials) -> CashFlowResult {
        guard let ocf = financials.operatingCashFlow else {
            return CashFlowResult(score: 50, status: .unknown, details: "Nakit akış verisi yok")
        }
        
        var score: Double = 50
        
        // 1. Nakit Akışı / Net Kar Oranı (Kalite) - %50 Puan
        if let netProfit = financials.netProfit, netProfit > 0 {
            let ratio = ocf / netProfit
            
            if ratio > 1.5 { score += 50 }
            else if ratio > 1.2 { score += 40 }
            else if ratio > 1.0 { score += 30 }
            else if ratio > 0.8 { score += 10 }
            else if ratio > 0 { score -= 10 }
            else { score -= 30 } // Kar var ama nakit yok (Tehlikeli)
        } else if let netProfit = financials.netProfit, netProfit < 0 {
            // Zarar eden şirket
            if ocf > 0 { score += 30 } // Zarar ama nakit üretiyor (Turnaround?)
            else { score -= 40 } // Hem zarar hem nakit yakıyor
        }
        
        // 2. Nakit Akışı Verimi (OCF / MarketCap) - %50 Puan
        if let mCap = financials.marketCap, mCap > 0 {
            let yield = (ocf / mCap) * 100
            
            // Mevduat faizi karşılaştırması yapılabilir ama basit tutuyoruz
            if yield > 15 { score += 50 } // Çok ucuz/Nakit zengini
            else if yield > 10 { score += 40 }
            else if yield > 5 { score += 20 }
            else if yield > 0 { score += 10 }
            else { score -= 20 }
        }
        
        // Normalize
        score = min(100, max(0, score))
        
        // Statü
        let status: CashFlowStatus
        if ocf < 0 {
            status = .burner
        } else if let netProfit = financials.netProfit, netProfit > 0 {
            let ratio = ocf / netProfit
            if ratio > 1.2 { status = .machine }
            else if ratio > 1.0 { status = .strong }
            else if ratio > 0.8 { status = .adequate }
            else { status = .weak }
        } else {
            status = ocf > 0 ? .adequate : .weak
        }
        
        let detailText = "Nakit: \(formatMoney(ocf))"
        
        return CashFlowResult(score: score, status: status, details: detailText)
    }
    
    private func formatMoney(_ amount: Double) -> String {
        if abs(amount) >= 1_000_000_000 {
            return String(format: "%.1f Mlyr TL", amount / 1_000_000_000)
        } else if abs(amount) >= 1_000_000 {
            return String(format: "%.1f Mn TL", amount / 1_000_000)
        } else {
            return String(format: "%.0f TL", amount)
        }
    }
}
