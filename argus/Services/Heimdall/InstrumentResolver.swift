import Foundation

/// Resolves Canonical Instruments to Provider-Specific Identifiers.
/// Example: .vix -> Yaho
/// Resolves Internal Strings ("VIX", "Hashtags") to Canonical Instruments.
@MainActor
final class InstrumentResolver {
    static let shared = InstrumentResolver()
    private init() {}
    
    // MARK: - Knowledge Base
    // Map: Internal ID (uppercased) -> CanonicalInstrument
    private let definitions: [String: CanonicalInstrument] = [
        // Macro / Economic
        "CPI": .cpi, "CPI_US": .cpi, "MACRO.CPI": .cpi,
        "LABOR": .labor, "UNEMP": .labor, "UNRATE": .labor, "MACRO.LABOR": .labor,
        "GROWTH": .growth, "GDP": .growth, "MACRO.GROWTH": .growth,
        "RATES": .rates, "US10Y": .rates, "MACRO.RATES": .rates, "MACRO.TNX": .tnx,
        "BOND2Y": .bond2y, "US2Y": .bond2y, "MACRO.BOND2Y": .bond2y,
        
        // Market / Indices
        "VIX": .vix, "VOLATILITY": .vix, "MACRO.VIX": .vix, "^VIX": .vix,
        "DXY": .dxy, "DOLLAR": .dxy, "MACRO.DXY": .dxy, "DX-Y.NYB": .dxy,
        "SP500": .spy, "SPY": .spy, "MACRO.SPY": .spy, "GSPC": .spy, "^GSPC": .spy,
        "NASDAQ": CanonicalInstrument(internalId: "NASDAQ", displayName: "Nasdaq 100", assetType: .index, yahooSymbol: "^IXIC", fredSeriesId: "NASDAQ100", twelveDataSymbol: "IXIC", sourceType: .market),
        "DJI": CanonicalInstrument(internalId: "DJI", displayName: "Dow Jones", assetType: .index, yahooSymbol: "^DJI", fredSeriesId: "DJIA", twelveDataSymbol: "DJI", sourceType: .market),
        
        // Commodities
        "GOLD": .gold, "XAU": .gold, "MACRO.GOLD": .gold, "GC=F": .gold,
        "SILVER": .silver, "XAG": .silver, "MACRO.SILVER": .silver, "SI=F": .silver,
        "OIL": .oil, "WTI": .oil, "MACRO.OIL": .oil, "CL=F": .oil, "CRUDE": .oil,
        "NATGAS": CanonicalInstrument(internalId: "NATGAS", displayName: "Doğalgaz", assetType: .commodity, yahooSymbol: "NG=F", fredSeriesId: "GASREGCOW", twelveDataSymbol: "NATGAS", sourceType: .market),
        
        // Crypto
        "BTC": .btc, "BITCOIN": .btc, "MACRO.BTC": .btc, "BTC-USD": .btc,
        "ETH": CanonicalInstrument(internalId: "ETH", displayName: "Ethereum", assetType: .crypto, yahooSymbol: "ETH-USD", fredSeriesId: nil, twelveDataSymbol: "ETH/USD", sourceType: .market),
        
        // FX
        "USDTRY": CanonicalInstrument(internalId: "USDTRY", displayName: "Dolar/TL", assetType: .forex, yahooSymbol: "USDTRY=X", fredSeriesId: "DEXUSTU", twelveDataSymbol: "USD/TRY", sourceType: .market),
        "EURUSD": CanonicalInstrument(internalId: "EURUSD", displayName: "Euro/Dolar", assetType: .forex, yahooSymbol: "EURUSD=X", fredSeriesId: "DEXUSEU", twelveDataSymbol: "EUR/USD", sourceType: .market)
    ]
    
    // MARK: - Resolution API
    
    func resolve(_ id: String) -> CanonicalInstrument {
        let key = id.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check Known Definitions
        if let known = definitions[key] {
            log(id, "Known", known.yahooSymbol ?? known.fredSeriesId ?? "Internal")
            return known
        }
        
        // 2. Check Raw Mappings (e.g. if passed exact Yahoo symbol)
        // If it starts with ^ (Yahoo Index) or contains =F (Future), assume Index/Commodity
        if key.hasPrefix("^") {
            return CanonicalInstrument(internalId: key, displayName: key, assetType: .index, yahooSymbol: key, fredSeriesId: nil, twelveDataSymbol: nil, sourceType: .market)
        }
        if key.hasSuffix("=X") { // Forex
            return CanonicalInstrument(internalId: key, displayName: key, assetType: .forex, yahooSymbol: key, fredSeriesId: nil, twelveDataSymbol: key.replacingOccurrences(of: "=X", with: ""), sourceType: .market)
        }
        
        // 3. Fallback: Assume Stock
        // "Using strict normalized symbol"
        log(id, "Fallback", "Stock")
        return CanonicalInstrument(internalId: key, displayName: key, assetType: .stock, yahooSymbol: key, fredSeriesId: nil, twelveDataSymbol: key, sourceType: .market)
    }
    
    // Convenience for Legacy Code passing CanonicalInstrument static
    func resolve(_ inst: CanonicalInstrument) -> CanonicalInstrument {
        return inst
    }
    
    private func log(_ input: String, _ method: String, _ mapped: String) {
        print("🧭 Resolver: \(input) -> \(method)(\(mapped))")
    }
}
