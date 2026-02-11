import Foundation

// MARK: - Atlas Sektör Benchmark Veritabanı
// 2024/2025 ortalama değerler (Yahoo Finance, S&P Global verileri)

final class AtlasSectorBenchmarks {
    static let shared = AtlasSectorBenchmarks()
    
    private init() {}
    
    // MARK: - Sektör Benchmark Verileri
    
    private let benchmarks: [String: AtlasSectorBenchmark] = [
        "Technology": AtlasSectorBenchmark(
            sector: "Technology",
            avgPE: 32.0,
            avgPB: 8.5,
            avgROE: 25.0,
            avgNetMargin: 18.0,
            avgDebtToEquity: 0.6,
            avgDividendYield: 0.8
        ),
        "Financial Services": AtlasSectorBenchmark(
            sector: "Financial Services",
            avgPE: 12.0,
            avgPB: 1.4,
            avgROE: 12.0,
            avgNetMargin: 25.0,
            avgDebtToEquity: 2.5,
            avgDividendYield: 2.8
        ),
        "Healthcare": AtlasSectorBenchmark(
            sector: "Healthcare",
            avgPE: 22.0,
            avgPB: 4.5,
            avgROE: 18.0,
            avgNetMargin: 12.0,
            avgDebtToEquity: 0.8,
            avgDividendYield: 1.5
        ),
        "Consumer Cyclical": AtlasSectorBenchmark(
            sector: "Consumer Cyclical",
            avgPE: 20.0,
            avgPB: 5.0,
            avgROE: 20.0,
            avgNetMargin: 8.0,
            avgDebtToEquity: 1.0,
            avgDividendYield: 1.2
        ),
        "Consumer Defensive": AtlasSectorBenchmark(
            sector: "Consumer Defensive",
            avgPE: 22.0,
            avgPB: 5.5,
            avgROE: 25.0,
            avgNetMargin: 10.0,
            avgDebtToEquity: 1.2,
            avgDividendYield: 2.5
        ),
        "Industrials": AtlasSectorBenchmark(
            sector: "Industrials",
            avgPE: 20.0,
            avgPB: 4.0,
            avgROE: 15.0,
            avgNetMargin: 8.0,
            avgDebtToEquity: 1.0,
            avgDividendYield: 1.8
        ),
        "Energy": AtlasSectorBenchmark(
            sector: "Energy",
            avgPE: 10.0,
            avgPB: 1.8,
            avgROE: 15.0,
            avgNetMargin: 10.0,
            avgDebtToEquity: 0.5,
            avgDividendYield: 4.0
        ),
        "Basic Materials": AtlasSectorBenchmark(
            sector: "Basic Materials",
            avgPE: 12.0,
            avgPB: 2.0,
            avgROE: 12.0,
            avgNetMargin: 8.0,
            avgDebtToEquity: 0.6,
            avgDividendYield: 2.5
        ),
        "Communication Services": AtlasSectorBenchmark(
            sector: "Communication Services",
            avgPE: 18.0,
            avgPB: 3.5,
            avgROE: 15.0,
            avgNetMargin: 15.0,
            avgDebtToEquity: 1.0,
            avgDividendYield: 1.0
        ),
        "Utilities": AtlasSectorBenchmark(
            sector: "Utilities",
            avgPE: 18.0,
            avgPB: 2.0,
            avgROE: 10.0,
            avgNetMargin: 12.0,
            avgDebtToEquity: 1.5,
            avgDividendYield: 3.5
        ),
        "Real Estate": AtlasSectorBenchmark(
            sector: "Real Estate",
            avgPE: 35.0,
            avgPB: 2.5,
            avgROE: 8.0,
            avgNetMargin: 20.0,
            avgDebtToEquity: 1.2,
            avgDividendYield: 4.0
        )
    ]
    
    // MARK: - Default (Tüm Piyasa Ortalaması)
    
    private let defaultBenchmark = AtlasSectorBenchmark(
        sector: "Market Average",
        avgPE: 20.0,
        avgPB: 3.5,
        avgROE: 15.0,
        avgNetMargin: 10.0,
        avgDebtToEquity: 0.8,
        avgDividendYield: 2.0
    )
    
    // MARK: - Public API
    
    func getBenchmark(for sector: String?) -> AtlasSectorBenchmark {
        guard let sector = sector else { return defaultBenchmark }
        
        // Exact match
        if let exact = benchmarks[sector] { return exact }
        
        // Partial match
        for (key, value) in benchmarks {
            if sector.contains(key) || key.contains(sector) { return value }
        }
        
        return defaultBenchmark
    }
    
    func getSectorAveragePE(for sector: String?) -> Double {
        getBenchmark(for: sector).avgPE
    }
    
    func getSectorAveragePB(for sector: String?) -> Double {
        getBenchmark(for: sector).avgPB
    }
    
    func getSectorAverageROE(for sector: String?) -> Double {
        getBenchmark(for: sector).avgROE
    }
}
