import SwiftUI

struct CompanyLogoView: View {
    let symbol: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 8

    // BIST mi kontrol et
    private var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS")
    }

    // Temiz sembol (.IS olmadan)
    private var cleanSymbol: String {
        symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
    }

    // Logo URL - BIST icin farkli kaynak
    private var logoUrl: URL? {
        if isBist {
            // BIST hisseleri icin logo kaynagi (Yahoo Finance veya bos)
            // Yahoo Finance bazen BIST logolarini da saglar
            return URL(string: "https://logo.clearbit.com/\(bistDomain)")
        }
        // Global hisseler icin Financial Modeling Prep
        return URL(string: "https://financialmodelingprep.com/image-stock/\(symbol.uppercased()).png")
    }

    // BIST sirketleri icin domain tahmini
    private var bistDomain: String {
        let domains: [String: String] = [
            "THYAO": "turkishairlines.com",
            "ASELS": "aselsan.com.tr",
            "KCHOL": "koc.com.tr",
            "AKBNK": "akbank.com",
            "GARAN": "garantibbva.com.tr",
            "SAHOL": "sabanci.com",
            "TUPRS": "tupras.com.tr",
            "EREGL": "erdemir.com.tr",
            "BIMAS": "bim.com.tr",
            "SISE": "sisecam.com.tr",
            "FROTO": "ford.com.tr",
            "TOASO": "tofas.com.tr",
            "TCELL": "turkcell.com.tr",
            "TTKOM": "turktelekom.com.tr",
            "PGSUS": "flypgs.com",
            "ARCLK": "arcelik.com.tr",
            "MGROS": "migros.com.tr",
            "ISCTR": "isbank.com.tr",
            "YKBNK": "yapikredi.com.tr",
            "VAKBN": "vakifbank.com.tr",
            "HALKB": "halkbank.com.tr"
        ]
        return domains[cleanSymbol] ?? "\(cleanSymbol.lowercased()).com.tr"
    }

    var body: some View {
        AsyncImage(url: logoUrl) { phase in
            switch phase {
            case .empty:
                placeholderView
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(Color.white)
                    .cornerRadius(cornerRadius)
            case .failure:
                fallbackView
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size, height: size)
    }

    var placeholderView: some View {
        ZStack {
            Theme.secondaryBackground
            ProgressView()
        }
        .frame(width: size, height: size)
        .cornerRadius(cornerRadius)
    }

    // Fallback: BIST icin Turk bayragi renkleri, Global icin mavi
    var fallbackView: some View {
        let bgColor = isBist ? Color.red.opacity(DesignTokens.Opacity.glassCard) : Theme.tint.opacity(0.1)
        let textColor = isBist ? Color.red : Theme.tint

        return ZStack {
            bgColor

            // Iki harfli kisaltma
            Text(cleanSymbol.prefix(2).uppercased())
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(width: size, height: size)
        .cornerRadius(cornerRadius)
    }
}
