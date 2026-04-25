import Foundation

/// Y6: SymbolResolver'ın atabileceği hata türleri.
/// Lenient `resolve` geriye dönük uyumluluk için log + pass-through yaparken
/// `resolveStrict` bu hataları fırlatır; network çağrısından önce çürük sembolleri reddeder.
enum SymbolResolverError: Error, LocalizedError {
    case emptySymbol
    case invalidCharacters(symbol: String)
    case tooLong(length: Int)

    var errorDescription: String? {
        switch self {
        case .emptySymbol:
            return "Sembol boş veya sadece boşluktan oluşuyor."
        case .invalidCharacters(let s):
            return "Sembol geçersiz karakter içeriyor: '\(s)'"
        case .tooLong(let n):
            return "Sembol çok uzun (\(n) karakter)."
        }
    }
}

/// "The Translator" - Resolves common symbol aliases to Provider-Specific tickers.
/// Especially for Yahoo Finance (e.g. SILVER -> SI=F).
struct SymbolResolver {
    static let shared = SymbolResolver()
    
    // Static Mappings
    private let yahooAliases: [String: String] = [
        "SILVER": "SI=F",
        "GOLD": "GC=F",
        "COPPER": "HG=F",
        "CRUDE_OIL": "CL=F",
        "OIL": "CL=F",
        "WTI": "CL=F",
        "CRUDE": "CL=F",
        "BRENT_OIL": "BZ=F",
        "BRENT": "BZ=F",
        "NAT_GAS": "NG=F",
        "VIX": "^VIX",
        "DXY": "DX-Y.NYB",
        "US10Y": "^TNX",
        "SPX": "^GSPC",
        "S&P500": "^GSPC",
        "SP500": "^GSPC",
        "NDX": "^IXIC",
        "DJI": "^DJI",
        "BTC": "BTC-USD",
        "ETH": "ETH-USD",
        "EURUSD": "EURUSD=X",
        "GBPUSD": "GBPUSD=X",
        "USDTRY": "USDTRY=X"
    ]
    
    /// Resolves `SILVER` to `SI=F` for Yahoo, or pass-through for others.
    /// Lenient sürüm — geçersiz girdide `validate` uyarı loglar, orijinali geri döner.
    /// Yeni/kritik call-site'lar `resolveStrict` tercih etmeli (network'e gitmeden fail-close).
    func resolve(_ symbol: String, for provider: ProviderTag) -> String {
        do {
            return try resolveStrict(symbol, for: provider)
        } catch {
            print("⚠️ SymbolResolver: \(error.localizedDescription) — pass-through kullanılıyor.")
            return symbol.uppercased()
        }
    }

    /// Y6: Strict sürüm — çürük sembolü provider'a hiç göndermez.
    /// Boş/whitespace/aşırı uzun/geçersiz karakter durumlarında throw atar; caller bu
    /// sembolü atlar (skip) ve diğer sembollerle devam eder. Bu sayede malformed URL
    /// üretip provider'ın 4xx/5xx döngüsüne girmiyoruz, rate quota'yı koruyoruz.
    func resolveStrict(_ symbol: String, for provider: ProviderTag) throws -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SymbolResolverError.emptySymbol }
        guard trimmed.count <= 20 else { throw SymbolResolverError.tooLong(length: trimmed.count) }

        // Geçerli karakter seti: borsa ticker notasyonları — alfanumerik + . - _ ^ = & /
        // Örn: "BTC-USD", "SI=F", "DX-Y.NYB", "^VIX", "BRK.B", "S&P500"
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_^=&/")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            throw SymbolResolverError.invalidCharacters(symbol: trimmed)
        }

        let upper = trimmed.uppercased()

        switch provider {
        case .yahoo:
            if let alias = yahooAliases[upper] {
                print("🔁 SymbolAlias: \(symbol) -> \(alias) (Provider: \(provider.rawValue))")
                return alias
            }
            if upper.hasSuffix(".IS") {
                return upper
            }
            if isBistSymbol(upper) {
                let bistSymbol = "\(upper).IS"
                print("🇹🇷 BIST Symbol: \(symbol) -> \(bistSymbol)")
                return bistSymbol
            }
            return upper

        case .eodhd:
            // EODHD kendi mapSymbol'ünü provider katmanında uyguluyor.
            return upper

        default:
            return upper
        }
    }
    
    // MARK: - BIST Detection
    // BIST 30 + Önemli BIST 100 sembolleri
    private let bistSymbols: Set<String> = [
        "THYAO", "ASELS", "KCHOL", "AKBNK", "GARAN", "SAHOL", "TUPRS", "EREGL",
        "BIMAS", "SISE", "PETKM", "SASA", "HEKTS", "FROTO", "TOASO", "ENKAI",
        "ISCTR", "YKBNK", "VAKBN", "HALKB", "PGSUS", "TAVHL", "TCELL", "TTKOM",
        "KOZAL", "KOZAA", "TKFEN", "MGROS", "SOKM", "AEFES", "ARCLK", "ALARK",
        "ASTOR", "BBRYO", "BRSAN", "CIMSA", "DOAS", "EGEEN", "EKGYO", "ENJSA",
        "GESAN", "KONTR", "ODAS", "OYAKC", "SMRTG", "ULKER", "VESTL", "YEOTK",
        "GUBRF", "ISMEN", "AKSEN", "BERA", "DOHOL", "EUPWR", "GLYHO", "IPEKE",
        "KORDS", "LOGO", "MAVI", "NETAS", "OTKAR", "PRKME", "QUAGR", "RYGYO",
        "TURSG", "TTRAK", "ZOREN"
    ]
    
    /// Sembol BIST mı?
    ///
    /// BUG FIX: Eskiden yalnızca `bistSymbols` set'ine bakıyordu. Set elle bakımlı
    /// (~67 sembol) — AYGAZ, AGHOL gibi BIST 100 dışı ama geçerli BIST hisseleri
    /// set'te olmadığından `.IS` suffix'li alım bile USD portföye düşüyordu.
    ///
    /// Yeni mantık: `.IS` suffix'i deterministik BIST sinyali. Suffix varsa
    /// tartışmasız BIST. Set sadece suffix'siz (çıplak) sembol girilirse
    /// fallback olarak kontrol edilir — listede var olmayan çıplak sembol
    /// USD kabul edilir (kullanıcı istiyorsa `.IS` ekleyebilir).
    func isBistSymbol(_ symbol: String) -> Bool {
        let upper = symbol.uppercased()
        if upper.hasSuffix(".IS") {
            return true
        }
        return bistSymbols.contains(upper)
    }
}
