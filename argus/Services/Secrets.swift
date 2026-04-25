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

    /// Gemini fallback key — ikinci üyelik. Birincil key 429 (quota) alırsa
    /// bu key devreye giriyor. İki hesap arasında round-robin için kullanılır.
    /// SADECE Info.plist'ten okunur (Secrets.xcconfig). Asla hardcode edilmez.
    /// 2026-04-22: Önceki commit'te yanlışlıkla hardcode'du, GitHub secret
    /// scanning yakaladı, key revoke edildi. Yeni key'i Secrets.xcconfig'e
    /// `GEMINI_KEY_BACKUP` ile ekle.
    static var geminiKeyBackup: String {
        value(for: "GEMINI_KEY_BACKUP")
    }

    /// Gemini key havuzu — birincil + backup. ChartPatternEngine ve GeminiClient
    /// 429 aldığında havuzdaki bir sonrakine geçer.
    static var geminiKeyPool: [String] {
        var pool: [String] = []
        if !geminiKey.isEmpty { pool.append(geminiKey) }
        if !geminiKeyBackup.isEmpty { pool.append(geminiKeyBackup) }
        return pool
    }

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

    /// Pinecone serverless endpoint'inin tam URL'i. Her abonenin kendi index'i
    /// olduğu için hardcode edilemez; Secrets.xcconfig'den gelir.
    /// Örnek: `https://<index>-<project>.svc.<region>.pinecone.io`
    /// Boşsa PineconeService `.notConfigured` döner, RAG engine graceful degrade eder.
    static var pineconeBaseURL: String { value(for: "PINECONE_BASE_URL") }

    static var dovizComKey: String { value(for: "DOVIZCOM_KEY") }
    static var borsaPyKey: String { value(for: "BORSAPY_KEY") }
    static var borsaPyURL: String { value(for: "BORSAPY_URL") }

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
        var borsaPyURL: String { Secrets.borsaPyURL }
    }

    private static func value(for key: String) -> String {
        if let info = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return info.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let env = ProcessInfo.processInfo.environment[key] ?? ""
        return env.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
