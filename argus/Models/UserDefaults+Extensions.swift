import Foundation

extension UserDefaults {
    private enum Keys {
        static let isAutoPilotLoggingEnabled = "isAutoPilotLoggingEnabled"
        static let bistCommissionRate = "trading.bistCommissionRate"
        static let globalCommissionRate = "trading.globalCommissionRate"
        static let bistWithholdingRate = "trading.bistWithholdingRate"
    }

    var isAutoPilotLoggingEnabled: Bool {
        get { return bool(forKey: Keys.isAutoPilotLoggingEnabled) }
        set { set(newValue, forKey: Keys.isAutoPilotLoggingEnabled) }
    }

    /// BIST komisyon oranı (ondalık, ör. 0.0015 = %0.15). Default 0.0
    /// (Midas/Garanti gibi sıfır komisyon aracılar yaygın).
    var bistCommissionRate: Double {
        get { return double(forKey: Keys.bistCommissionRate) }
        set { set(newValue, forKey: Keys.bistCommissionRate) }
    }

    /// US/Global komisyon oranı (ondalık, ör. 0.001 = %0.1). Default 0.0
    /// (Alpaca, IBKR Lite gibi komisyonsuz aracılar).
    var globalCommissionRate: Double {
        get { return double(forKey: Keys.globalCommissionRate) }
        set { set(newValue, forKey: Keys.globalCommissionRate) }
    }

    /// BIST hisse kâr stopajı (ondalık, ör. 0.15). Default 0.0
    /// (2026 itibariyle hisse senedi kazancı stopaj istisnası aktif).
    /// Kullanıcı isterse devreye alır; ArgusBacktestEngine sell/end-position
    /// path'inde pozitif segment PnL'e uygulanır.
    var bistWithholdingRate: Double {
        get { return double(forKey: Keys.bistWithholdingRate) }
        set { set(newValue, forKey: Keys.bistWithholdingRate) }
    }
}
