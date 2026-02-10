import Foundation

enum Secrets {
    // MARK: - API Keys
    // Keys are read from Info.plist (injected from Secrets.xcconfig) or environment variables.
    // This tracked file must never contain real secret literals.

    // LLM API Keys
    static var groqKey: String { value(for: "GROQ_KEY") }
    static var glmKey: String { value(for: "GLM_KEY") }
    static var geminiKey: String { value(for: "GEMINI_KEY") }
    static var deepSeekKey: String { value(for: "DEEPSEEK_KEY") }

    // Market Data API Keys
    static var twelveDataKey: String { value(for: "TWELVE_DATA_KEY") }
    static var fmpKey: String { value(for: "FMP_KEY") }
    static var finnhubKey: String { value(for: "FINNHUB_KEY") }
    static var tiingoKey: String { value(for: "TIINGO_KEY") }
    static var marketStackKey: String { value(for: "MARKETSTACK_KEY") }
    static var alphaVantageKey: String { value(for: "ALPHA_VANTAGE_KEY") }
    static var eodhdKey: String { value(for: "EODHD_KEY") }
    static var fredKey: String { value(for: "FRED_KEY") }
    static var pineconeKey: String { value(for: "PINECONE_KEY") }
    static var dovizComKey: String { value(for: "DOVIZCOM_KEY") }
    static var borsaPyKey: String { value(for: "BORSAPY_KEY") }

    // MARK: - Legacy Support (Singleton Adapter)
    static let shared = SecretsLegacyAdapter()

    struct SecretsLegacyAdapter {
        var twelveData: String { Secrets.twelveDataKey }
        var fmp: String { Secrets.fmpKey }
        var finnhub: String { Secrets.finnhubKey }
        var tiingo: String { Secrets.tiingoKey }
        var marketStack: String { Secrets.marketStackKey }
        var alphaVantage: String { Secrets.alphaVantageKey }
        var eodhd: String { Secrets.eodhdKey }
        var gemini: String { Secrets.geminiKey }
        var glm: String { Secrets.glmKey }
        var groq: String { Secrets.groqKey }
        var deepSeek: String { Secrets.deepSeekKey }
        var fred: String { Secrets.fredKey }
        var dovizCom: String { Secrets.dovizComKey }
        var borsaPy: String { Secrets.borsaPyKey }
    }

    private static func value(for key: String) -> String {
        if let info = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return info.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let env = ProcessInfo.processInfo.environment[key] ?? ""
        return env.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
