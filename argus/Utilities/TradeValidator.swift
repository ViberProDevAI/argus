import Foundation

// MARK: - Trade Validation Types

/// Trade validation result
struct TradeValidationResult {
    let isValid: Bool
    let error: TradeValidationError?
    
    static let success = TradeValidationResult(isValid: true, error: nil)
    
    static func failure(_ error: TradeValidationError) -> TradeValidationResult {
        TradeValidationResult(isValid: false, error: error)
    }
}

/// Trade validation errors
enum TradeValidationError: Error, LocalizedError {
    case emptySymbol
    case invalidSymbolFormat(String)
    case invalidQuantity(Double)
    case invalidPrice(Double)
    case insufficientBalance(required: Double, available: Double)
    case insufficientPosition(owned: Double, requested: Double)
    case marketClosed(String)
    case symbolNotFound(String)
    case priceUnavailable(String)
    case duplicateTrade(String)
    case riskLimitExceeded(String)
    
    var errorDescription: String? {
        switch self {
        case .emptySymbol:
            return "Sembol boş olamaz"
        case .invalidSymbolFormat(let symbol):
            return "Geçersiz sembol formatı: \(symbol)"
        case .invalidQuantity(let qty):
            return "Geçersiz miktar: \(qty). Miktar 0'dan büyük olmalı."
        case .invalidPrice(let price):
            return "Geçersiz fiyat: \(price). Fiyat 0'dan büyük olmalı."
        case .insufficientBalance(let required, let available):
            return "Bakiye yetersiz. Gereken: \(String(format: "%.2f", required)), Mevcut: \(String(format: "%.2f", available))"
        case .insufficientPosition(let owned, let requested):
            return "Pozisyon yetersiz. Sahip olunan: \(String(format: "%.2f", owned)), İstenen: \(String(format: "%.2f", requested))"
        case .marketClosed(let market):
            return "\(market) piyasası kapalı"
        case .symbolNotFound(let symbol):
            return "Sembol bulunamadı: \(symbol)"
        case .priceUnavailable(let symbol):
            return "\(symbol) için fiyat bilgisi alınamadı"
        case .duplicateTrade(let symbol):
            return "Bu sembol için zaten açık pozisyon var: \(symbol)"
        case .riskLimitExceeded(let reason):
            return "Risk limiti aşıldı: \(reason)"
        }
    }
}

// MARK: - Trade Validator

/// Central trade validation service
struct TradeValidator {
    
    // MARK: - Configuration
    
    struct Config {
        static var maxSymbolLength: Int = 15
        static var maxQuantity: Double = 1_000_000
        static var minQuantity: Double = 0.00001 // For fractional shares
        static var maxPrice: Double = 1_000_000
    }
    
    // MARK: - Validation Methods
    
    /// Validate buy trade parameters
    static func validateBuy(
        symbol: String,
        quantity: Double,
        price: Double?,
        availableBalance: Double,
        isBistMarketOpen: Bool,
        isGlobalMarketOpen: Bool
    ) -> TradeValidationResult {
        
        // 1. Symbol validation
        if let error = validateSymbol(symbol) {
            return .failure(error)
        }
        
        // 2. Quantity validation
        if let error = validateQuantity(quantity) {
            return .failure(error)
        }
        
        // 3. Price validation
        if let p = price, p <= 0 {
            return .failure(.invalidPrice(p))
        }
        
        // 4. Market status check
        let isBist = symbol.uppercased().hasSuffix(".IS")
        if isBist && !isBistMarketOpen {
            return .failure(.marketClosed("BIST"))
        }
        if !isBist && !isGlobalMarketOpen {
            return .failure(.marketClosed("Global"))
        }
        
        // 5. Balance check
        if let actualPrice = price {
            let totalCost = quantity * actualPrice * 1.002 // Include estimated fees
            if totalCost > availableBalance {
                return .failure(.insufficientBalance(required: totalCost, available: availableBalance))
            }
        }
        
        return .success
    }
    
    /// Validate sell trade parameters
    static func validateSell(
        symbol: String,
        quantity: Double,
        ownedQuantity: Double,
        isBistMarketOpen: Bool,
        isGlobalMarketOpen: Bool
    ) -> TradeValidationResult {
        
        // 1. Symbol validation
        if let error = validateSymbol(symbol) {
            return .failure(error)
        }
        
        // 2. Quantity validation
        if let error = validateQuantity(quantity) {
            return .failure(error)
        }
        
        // 3. Market status check
        let isBist = symbol.uppercased().hasSuffix(".IS")
        if isBist && !isBistMarketOpen {
            return .failure(.marketClosed("BIST"))
        }
        if !isBist && !isGlobalMarketOpen {
            return .failure(.marketClosed("Global"))
        }
        
        // 4. Position check
        if quantity > ownedQuantity {
            return .failure(.insufficientPosition(owned: ownedQuantity, requested: quantity))
        }
        
        return .success
    }
    
    // MARK: - Helper Methods
    
    private static func validateSymbol(_ symbol: String) -> TradeValidationError? {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .emptySymbol
        }
        
        if trimmed.count > Config.maxSymbolLength {
            return .invalidSymbolFormat(symbol)
        }
        
        // Basic format check (alphanumeric + allowed special chars)
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-/"))
        if trimmed.unicodeScalars.contains(where: { !allowedChars.contains($0) }) {
            return .invalidSymbolFormat(symbol)
        }
        
        return nil
    }
    
    private static func validateQuantity(_ quantity: Double) -> TradeValidationError? {
        if quantity <= 0 {
            return .invalidQuantity(quantity)
        }
        
        if quantity < Config.minQuantity {
            return .invalidQuantity(quantity)
        }
        
        if quantity > Config.maxQuantity {
            return .invalidQuantity(quantity)
        }
        
        if quantity.isNaN || quantity.isInfinite {
            return .invalidQuantity(quantity)
        }
        
        return nil
    }
}
