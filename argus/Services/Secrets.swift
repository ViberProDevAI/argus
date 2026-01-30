import Foundation

enum Secrets {
    // MARK: - API Keys (Info.plist'ten güvenli okuma)

    private static func getKey(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$(") else {
            return ""
        }
        return value
    }

    static var twelveDataKey: String { getKey("TWELVE_DATA_KEY") }
    static var fmpKey: String { getKey("FMP_KEY") }
    static var tiingoKey: String { getKey("TIINGO_KEY") }
    static var marketStackKey: String { getKey("MARKETSTACK_KEY") }
    static var groqKey: String { getKey("GROQ_KEY") }
    static var alphaVantageKey: String { getKey("ALPHA_VANTAGE_KEY") }
    static var eodhdKey: String { getKey("EODHD_KEY") }
    static var geminiKey: String {
        let key = getKey("GEMINI_KEY")
        return key.isEmpty || key.hasPrefix("$") ? "REDACTED_GEMINI_KEY" : key
    }
    static var deepSeekKey: String { getKey("DEEPSEEK_KEY") }
    static var fredKey: String { 
        let k = getKey("FRED_KEY")
        return k.isEmpty ? "REDACTED_FRED_KEY" : k 
    }
    static var pineconeKey: String { getKey("PINECONE_KEY") }
    
    // MARK: - Local / Hardcoded Keys (Simülasyon İçin - Geçici)
    // Gerçek prod ortamında bunlar Info.plist/Keychain'e taşınmalı
    static let dovizComKey = "REDACTED_DOVIZCOM_KEY"
    static let borsaPyKey = "REDACTED_BORSAPY_KEY"

    // MARK: - Legacy Support (Singleton Adapter)
    static let shared = SecretsLegacyAdapter()

    struct SecretsLegacyAdapter {
        var twelveData: String { Secrets.twelveDataKey }
        var fmp: String { Secrets.fmpKey }
        var tiingo: String { Secrets.tiingoKey }
        var marketStack: String { Secrets.marketStackKey }
        var alphaVantage: String { Secrets.alphaVantageKey }
        var eodhd: String { Secrets.eodhdKey }
        var gemini: String { Secrets.geminiKey }
        var groq: String { Secrets.groqKey }
        var deepSeek: String { Secrets.deepSeekKey }

        var fred: String { Secrets.fredKey }
        var dovizCom: String { Secrets.dovizComKey }
        var borsaPy: String { Secrets.borsaPyKey }
    }
}
