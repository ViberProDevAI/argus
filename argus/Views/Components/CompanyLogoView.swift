import Combine
import SwiftUI

// MARK: - LogoCache (singleton)
//
// 2026-04-22 logo-fix-3: AsyncImage + stage chain da LazyVStack'te
// tutarsızdı. Singleton cache + detached Task ile sağlamlaştırıldı.
// Bir sembol bir kez fetch edilir, sonuç (UIImage veya nil) `@Published`
// kalır; view recycle olsa da state kaybolmaz.
@MainActor
final class LogoCache: ObservableObject {
    static let shared = LogoCache()

    @Published private(set) var images: [String: UIImage] = [:]
    private var failed: Set<String> = []
    private var inflight: Set<String> = []

    private init() {}

    /// Senkron lookup — varsa image döner, yoksa fetch'i tetikler ve nil döner.
    func logo(for symbol: String) -> UIImage? {
        let key = symbol.uppercased()
        if let img = images[key] { return img }
        if failed.contains(key) { return nil }
        if !inflight.contains(key) {
            inflight.insert(key)
            Task {
                let img = await Self.fetch(symbol: key)
                self.inflight.remove(key)
                if let img {
                    self.images[key] = img
                } else {
                    self.failed.insert(key)
                }
            }
        }
        return nil
    }

    // MARK: - Fetch pipeline

    private static func fetch(symbol: String) async -> UIImage? {
        let clean = symbol.replacingOccurrences(of: ".IS", with: "")
        let isBist = symbol.hasSuffix(".IS")

        var urls: [URL] = []
        if isBist {
            let domain = bistDomain(for: clean)
            if let u = URL(string: "https://logo.clearbit.com/\(domain)") { urls.append(u) }
            if let u = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128") {
                urls.append(u)
            }
        } else {
            // Global: FMP primary (test edildi, AAPL/GOOGL/NVDA/PLTR 200 PNG),
            // IEX Cloud Storage fallback (test edildi, 128x128 PNG döner),
            // Clearbit domain üçüncü şans.
            if let u = URL(string: "https://financialmodelingprep.com/image-stock/\(clean).png") {
                urls.append(u)
            }
            if let u = URL(string: "https://storage.googleapis.com/iex/api/logos/\(clean).png") {
                urls.append(u)
            }
            if let domain = wellKnownGlobalDomain(for: clean),
               let u = URL(string: "https://logo.clearbit.com/\(domain)") {
                urls.append(u)
            }
        }

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        cfg.timeoutIntervalForResource = 10
        cfg.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024,
                                 diskCapacity: 32 * 1024 * 1024,
                                 diskPath: "argus-logo-cache")
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: cfg)

        for url in urls {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await session.data(for: req)
                if let http = response as? HTTPURLResponse {
                    guard (200..<300).contains(http.statusCode) else { continue }
                    // content-type image/* olmalı, svg bile olsa UIImage parse edemiyor
                    let ct = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                    if ct.contains("svg") { continue }
                }
                if let image = UIImage(data: data), image.size.width > 4 {
                    return image
                }
            } catch {
                continue
            }
        }
        return nil
    }

    // MARK: - Domain haritaları (statik)

    private static func bistDomain(for symbol: String) -> String {
        let domains: [String: String] = [
            "THYAO": "turkishairlines.com", "ASELS": "aselsan.com.tr",
            "KCHOL": "koc.com.tr",          "AKBNK": "akbank.com",
            "GARAN": "garantibbva.com.tr",  "SAHOL": "sabanci.com",
            "TUPRS": "tupras.com.tr",       "EREGL": "erdemir.com.tr",
            "BIMAS": "bim.com.tr",          "SISE":  "sisecam.com.tr",
            "FROTO": "ford.com.tr",         "TOASO": "tofas.com.tr",
            "TCELL": "turkcell.com.tr",     "TTKOM": "turktelekom.com.tr",
            "PGSUS": "flypgs.com",          "ARCLK": "arcelik.com.tr",
            "MGROS": "migros.com.tr",       "ISCTR": "isbank.com.tr",
            "YKBNK": "yapikredi.com.tr",    "VAKBN": "vakifbank.com.tr",
            "HALKB": "halkbank.com.tr",     "KOZAL": "kozaltin.com.tr",
            "KOZAA": "kozaanadolu.com.tr",  "DOHOL": "dogusgrubu.com",
            "ENKAI": "enka.com",            "PETKM": "petkim.com.tr",
            "TKFEN": "tekfen.com.tr",       "TAVHL": "tav.aero",
            "CCOLA": "coca-cola.com.tr",    "HEKTS": "hektas.com.tr",
            "YATAS": "yatas.com.tr"
        ]
        return domains[symbol] ?? "\(symbol.lowercased()).com.tr"
    }

    private static func wellKnownGlobalDomain(for symbol: String) -> String? {
        let domains: [String: String] = [
            "AAPL": "apple.com",     "MSFT": "microsoft.com",
            "GOOGL": "abc.xyz",      "GOOG":  "abc.xyz",
            "AMZN": "amazon.com",    "NVDA":  "nvidia.com",
            "META": "meta.com",      "TSLA":  "tesla.com",
            "NFLX": "netflix.com",   "AMD":   "amd.com",
            "INTC": "intel.com",     "CRM":   "salesforce.com",
            "ORCL": "oracle.com",    "ADBE":  "adobe.com",
            "PYPL": "paypal.com",    "DIS":   "disney.com",
            "BA":   "boeing.com",    "KO":    "coca-colacompany.com",
            "PEP":  "pepsico.com",   "MCD":   "mcdonalds.com",
            "NKE":  "nike.com",      "V":     "visa.com",
            "MA":   "mastercard.com","JPM":   "jpmorganchase.com",
            "BAC":  "bankofamerica.com", "WMT": "walmart.com",
            "COST": "costco.com",    "UBER":  "uber.com",
            "ABNB": "airbnb.com",    "PLTR":  "palantir.com",
            "SHOP": "shopify.com",   "SQ":    "block.xyz",
            "SPOT": "spotify.com"
        ]
        return domains[symbol]
    }
}

// MARK: - CompanyLogoView

struct CompanyLogoView: View {
    let symbol: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 8

    @ObservedObject private var cache = LogoCache.shared

    private var cleanSymbol: String {
        symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
    }

    var body: some View {
        ZStack {
            // Gradient fallback her zaman arkada — network hatası/beklemede
            // görünür kalır, logo geldiğinde üstüne oturur.
            v5GradientFallback

            if let img = cache.logo(for: symbol) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                                style: .continuous))
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: cache.images[symbol.uppercased()] != nil)
    }

    // MARK: - V5 gradient fallback

    private var v5GradientFallback: some View {
        let colors = Self.gradientColors(for: cleanSymbol)
        return ZStack {
            LinearGradient(colors: colors,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Text(cleanSymbol.prefix(2).uppercased())
                .font(.system(size: size * 0.38, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    static func gradientColors(for symbol: String) -> [Color] {
        let hash = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        switch hash % 6 {
        case 0: return [Color(hex: "1A365D"), Color(hex: "3B82F6")]
        case 1: return [Color(hex: "3B0A0A"), Color(hex: "EF4444")]
        case 2: return [Color(hex: "112437"), Color(hex: "60A5FA")]
        case 3: return [Color(hex: "0B1426"), Color(hex: "22D3EE")]
        case 4: return [Color(hex: "2A1F0A"), Color(hex: "C8A971")] // warm tan (eski: A78BFA mor — AI-tell)
        default: return [Color(hex: "1F2A0A"), Color(hex: "22C55E")]
        }
    }
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.background.ignoresSafeArea()
        VStack(spacing: 12) {
            HStack {
                CompanyLogoView(symbol: "AAPL", size: 56)
                CompanyLogoView(symbol: "GOOGL", size: 56)
                CompanyLogoView(symbol: "NVDA", size: 56)
                CompanyLogoView(symbol: "TSLA", size: 56)
            }
            HStack {
                CompanyLogoView(symbol: "THYAO.IS", size: 56)
                CompanyLogoView(symbol: "ASELS.IS", size: 56)
                CompanyLogoView(symbol: "ZZZZZ.IS", size: 56)
            }
        }
    }
}
