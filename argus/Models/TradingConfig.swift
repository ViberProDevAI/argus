import Foundation

// MARK: - Trading Configuration
// Magic numbers yerine merkezi configuration dosyası

struct TradingConfig {
    
    // MARK: - Default Instance
    
    static let `default` = TradingConfig()
    
    // MARK: - Risk Management
    
    /// Tek pozisyon için maksimum risk (equity yüzdesi)
    var maxPositionRisk: Double = 0.01 // 1%
    
    /// Toplam portfolio exposure limiti
    var maxPortfolioExposure: Double = 0.10 // 10%
    
    /// Minimum pozisyon tutma süresi (saniye)
    var minimumHoldingPeriod: TimeInterval = 1800 // 30 dakika
    
    /// Maximum pozisyon sayısı
    var maxPositionCount: Int = 20
    
    /// Stop loss varsayılan yüzdesi
    var defaultStopLossPercent: Double = 0.05 // 5%
    
    /// Take profit varsayılan yüzdesi
    var defaultTakeProfitPercent: Double = 0.10 // 10%
    
    // MARK: - AutoPilot
    
    /// AutoPilot tarama aralığı (saniye)
    var scanInterval: TimeInterval = 60 // 1 dakika
    
    /// Maximum Hermes (haber-bazlı) pozisyon sayısı
    var maxHermesPositions: Int = 5
    
    /// Scout handover için minimum skor
    var scoutMinimumScore: Double = 85.0
    
    /// Buy kararı için minimum skor
    var buyMinimumScore: Double = 65.0
    
    /// Sell kararı için maximum skor
    var sellMaximumScore: Double = 35.0
    
    // MARK: - Cache TTLs (Time To Live)
    
    /// Quote cache süresi (saniye)
    var quoteTTL: TimeInterval = 15
    
    /// Candle cache süresi (saniye)
    var candlesTTL: TimeInterval = 300 // 5 dakika
    
    /// Fundamental data cache süresi (saniye)
    var fundamentalsTTL: TimeInterval = 3600 // 1 saat
    
    /// Profile cache süresi (saniye)
    var profileTTL: TimeInterval = 86400 // 24 saat
    
    /// Macro data cache süresi (saniye)
    var macroTTL: TimeInterval = 300 // 5 dakika
    
    /// News cache süresi (saniye)
    var newsTTL: TimeInterval = 600 // 10 dakika
    
    // MARK: - Scoring Weights
    
    /// Orion (teknik) ağırlık
    var orionWeight: Double = 0.30
    
    /// Atlas (fundamental) ağırlık
    var atlasWeight: Double = 0.30
    
    /// Aether (makro) ağırlık
    var aetherWeight: Double = 0.25
    
    /// Hermes (haber) ağırlık
    var hermesWeight: Double = 0.15
    
    // MARK: - Market Hours
    
    /// BIST açılış saati (saat)
    var bistOpenHour: Int = 10
    
    /// BIST kapanış saati (saat:dakika -> 18:10)
    var bistCloseHour: Int = 18
    var bistCloseMinute: Int = 10
    
    /// US market açılış saati (Eastern Time, saat)
    var usMarketOpenHour: Int = 9
    var usMarketOpenMinute: Int = 30
    
    /// US market kapanış saati (Eastern Time, saat)
    var usMarketCloseHour: Int = 16
    
    // MARK: - Fees
    
    /// Varsayılan işlem ücreti yüzdesi
    var defaultCommissionPercent: Double = 0.001 // 0.1%
    
    /// Minimum işlem ücreti
    var minimumCommission: Double = 1.0 // $1
    
    // MARK: - UI
    
    /// Log listesinde maximum kayıt
    var maxLogEntries: Int = 100
    
    /// Pozisyon kartı için maksimum görüntüleme sayısı
    var maxVisiblePositions: Int = 50
    
    // MARK: - Convenience Methods
    
    /// Pozisyon için maksimum değer hesapla
    func maxPositionValue(for equity: Double) -> Double {
        equity * maxPositionRisk
    }
    
    /// Portfolio için maksimum exposure hesapla
    func maxExposureValue(for equity: Double) -> Double {
        equity * maxPortfolioExposure
    }
}

// MARK: - UserDefaults Integration

extension TradingConfig {
    
    /// UserDefaults'tan config yükle
    static func load() -> TradingConfig {
        var config = TradingConfig.default
        
        let defaults = UserDefaults.standard
        
        if let risk = defaults.object(forKey: "config.maxPositionRisk") as? Double {
            config.maxPositionRisk = risk
        }
        if let exposure = defaults.object(forKey: "config.maxPortfolioExposure") as? Double {
            config.maxPortfolioExposure = exposure
        }
        if let interval = defaults.object(forKey: "config.scanInterval") as? TimeInterval {
            config.scanInterval = interval
        }
        
        return config
    }
    
    /// UserDefaults'a config kaydet
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(maxPositionRisk, forKey: "config.maxPositionRisk")
        defaults.set(maxPortfolioExposure, forKey: "config.maxPortfolioExposure")
        defaults.set(scanInterval, forKey: "config.scanInterval")
    }
}
