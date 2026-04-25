import Foundation

/// Heimdall 5.5: Canonical Instrument Definition
/// Normalized model for any asset (Stock, ETF, Macro Series, Index).
struct CanonicalInstrument: Sendable, Codable, Equatable {
    let internalId: String       // "VIX", "AAPL", "CPI"
    let displayName: String
    let assetType: AssetType
    
    // Provider Mappings
    let yahooSymbol: String?     // "^VIX", "AAPL"
    let fredSeriesId: String?    // "VIXCLS", "CPIAUCSL"
    let twelveDataSymbol: String? // "VIX", "XAU/USD"
    
    // Legacy / Raw Value support for migration
    var rawValue: String { internalId }
    
    enum SourceType: String, Sendable, Codable {
        case market        // Traded Asset (Yahoo, 12D, EODHD)
        case macroSeries   // Economic Series (FRED)
    }
    
    let sourceType: SourceType
    
    // MARK: - Legacy Constants (Backward Compat)
    // Macro
    static let cpi = CanonicalInstrument(internalId: "macro.cpi", displayName: "TÜFE (CPI)", assetType: .index, yahooSymbol: nil, fredSeriesId: "CPIAUCSL", twelveDataSymbol: nil, sourceType: .macroSeries)
    static let labor = CanonicalInstrument(internalId: "macro.labor", displayName: "İşsizlik", assetType: .index, yahooSymbol: nil, fredSeriesId: "UNRATE", twelveDataSymbol: nil, sourceType: .macroSeries)
    static let growth = CanonicalInstrument(internalId: "macro.growth", displayName: "Büyüme (GDP)", assetType: .index, yahooSymbol: nil, fredSeriesId: "GDPC1", twelveDataSymbol: nil, sourceType: .macroSeries)
    static let rates = CanonicalInstrument(internalId: "macro.rates", displayName: "Faizler (10Y)", assetType: .index, yahooSymbol: "^TNX", fredSeriesId: "DGS10", twelveDataSymbol: "TNX", sourceType: .market) // Market because we use TNX for candles
    
    // Market / Indicators
    static let vix = CanonicalInstrument(internalId: "macro.vix", displayName: "Volatilite (VIX)", assetType: .index, yahooSymbol: "^VIX", fredSeriesId: "VIXCLS", twelveDataSymbol: "VIX", sourceType: .market)
    static let dxy = CanonicalInstrument(internalId: "macro.dxy", displayName: "DXY Endeksi", assetType: .index, yahooSymbol: "DX-Y.NYB", fredSeriesId: nil, twelveDataSymbol: "DXY", sourceType: .market)
    static let gold = CanonicalInstrument(internalId: "macro.gold", displayName: "Altın", assetType: .etf, yahooSymbol: "GLD", fredSeriesId: nil, twelveDataSymbol: "XAU/USD", sourceType: .market)
    static let silver = CanonicalInstrument(internalId: "macro.silver", displayName: "Gümüş", assetType: .etf, yahooSymbol: "SI=F", fredSeriesId: nil, twelveDataSymbol: "XAG/USD", sourceType: .market)
    static let oil = CanonicalInstrument(internalId: "macro.oil", displayName: "Petrol", assetType: .etf, yahooSymbol: "CL=F", fredSeriesId: "DCOILWTICO", twelveDataSymbol: "WTI", sourceType: .market)
    static let btc = CanonicalInstrument(internalId: "macro.btc", displayName: "Bitcoin", assetType: .crypto, yahooSymbol: "BTC-USD", fredSeriesId: nil, twelveDataSymbol: "BTC/USD", sourceType: .market)
    static let spy = CanonicalInstrument(internalId: "macro.spy", displayName: "S&P 500", assetType: .etf, yahooSymbol: "SPY", fredSeriesId: nil, twelveDataSymbol: "SPY", sourceType: .market)
    
    // Legacy Cases
    static let tnx = rates
    static let bond2y = CanonicalInstrument(internalId: "macro.bond2y", displayName: "2 Yıl Tahvil", assetType: .index, yahooSymbol: nil, fredSeriesId: "DGS2", twelveDataSymbol: nil, sourceType: .macroSeries) // DGS2 is FRED usually, unless we map to market ticker
    static let claims = CanonicalInstrument(internalId: "macro.claims", displayName: "İşsizlik Başvuruları", assetType: .index, yahooSymbol: nil, fredSeriesId: "ICSA", twelveDataSymbol: nil, sourceType: .macroSeries) // Initial Jobless Claims (Weekly - Leading Indicator)
    static let general = CanonicalInstrument(internalId: "general", displayName: "Genel", assetType: .stock, yahooSymbol: nil, fredSeriesId: nil, twelveDataSymbol: nil, sourceType: .market)
    static let trend = CanonicalInstrument(internalId: "macro.trend", displayName: "Piyasa Trendi", assetType: .index, yahooSymbol: nil, fredSeriesId: nil, twelveDataSymbol: nil, sourceType: .market)
}
