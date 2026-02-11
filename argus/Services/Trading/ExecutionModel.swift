import Foundation

// MARK: - Execution Model
/// Gerçekçi trade execution simülasyonu - slippage, komisyon, likidite

struct ExecutionModel: Codable, Sendable {
    // MARK: - Configuration
    
    /// Market slippage (spread bazlı) - genelde %0.02-0.10
    let slippagePct: Double
    
    /// Broker komisyonu (% olarak)
    let commissionPct: Double
    
    /// Sabit komisyon (trade başına)
    let fixedCommission: Double
    
    /// Maksimum pozisyon büyüklüğü (günlük hacmin yüzdesi)
    let maxVolumeParticipation: Double
    
    /// Minimum işlem tutarı
    let minTradeAmount: Double
    
    // MARK: - Presets
    
    /// Standart retail broker (Midas, Garanti vs)
    /// Standart retail broker (Midas, Garanti vs)
    static var retailTR: ExecutionModel {
        ExecutionModel(
            slippagePct: 0.05,           // %0.05 slippage
            commissionPct: 0.15,         // %0.15 komisyon
            fixedCommission: 0.0,
            maxVolumeParticipation: 2.0, // Günlük hacmin %2'si
            minTradeAmount: 100.0        // Min 100 TL
        )
    }
    
    /// US Broker (Interactive Brokers, Alpaca)
    /// US Broker (Interactive Brokers, Alpaca)
    static var retailUS: ExecutionModel {
        ExecutionModel(
            slippagePct: 0.02,           // %0.02 slippage (daha likit)
            commissionPct: 0.0,          // Komisyon yok (Alpaca)
            fixedCommission: 0.0,
            maxVolumeParticipation: 1.0, // Günlük hacmin %1'i
            minTradeAmount: 1.0          // Min $1
        )
    }
    
    /// Agresif trading (yüksek slippage varsayımı)
    /// Agresif trading (yüksek slippage varsayımı)
    static var conservative: ExecutionModel {
        ExecutionModel(
            slippagePct: 0.10,           // %0.10 slippage
            commissionPct: 0.20,         // %0.20 komisyon
            fixedCommission: 5.0,        // $5 sabit
            maxVolumeParticipation: 0.5, // Günlük hacmin %0.5'i
            minTradeAmount: 500.0
        )
    }
    
    /// Backtest için default (orta seviye)
    /// Backtest için default (orta seviye)
    static var backtest: ExecutionModel {
        ExecutionModel(
            slippagePct: 0.03,
            commissionPct: 0.10,
            fixedCommission: 0.0,
            maxVolumeParticipation: 2.0,
            minTradeAmount: 50.0
        )
    }
    
    /// Default wrapper for market operations
    /// Default wrapper for market operations
    static var marketWrapper: ExecutionModel { ExecutionModel.retailUS }
    
    // MARK: - Execution Calculation
    
    /// Alış fiyatını hesapla (ask tarafına slippage ekle)
    func calculateBuyPrice(marketPrice: Double, spread: Double? = nil) -> Double {
        let effectiveSpread = spread ?? (marketPrice * slippagePct / 100.0)
        return marketPrice + effectiveSpread
    }
    
    /// Satış fiyatını hesapla (bid tarafına slippage çıkar)
    func calculateSellPrice(marketPrice: Double, spread: Double? = nil) -> Double {
        let effectiveSpread = spread ?? (marketPrice * slippagePct / 100.0)
        return marketPrice - effectiveSpread
    }
    
    /// Toplam komisyon hesapla
    func calculateCommission(tradeValue: Double) -> Double {
        return fixedCommission + (tradeValue * commissionPct / 100.0)
    }
    
    /// Toplam trade maliyeti (slippage + komisyon)
    func calculateTotalCost(tradeValue: Double, isBuy: Bool) -> Double {
        let slippageCost = tradeValue * slippagePct / 100.0
        let commission = calculateCommission(tradeValue: tradeValue)
        return slippageCost + commission
    }
    
    /// Maksimum işlem büyüklüğü (likidite kısıtı)
    func maxOrderSize(dailyVolume: Double, price: Double) -> Double {
        let maxShares = (dailyVolume * maxVolumeParticipation / 100.0)
        return maxShares * price
    }
    
    /// Trade yapılabilir mi kontrol et
    func canExecute(orderValue: Double, dailyVolume: Double, price: Double) -> ExecutionValidation {
        // 1. Minimum tutar kontrolü
        if orderValue < minTradeAmount {
            return ExecutionValidation(
                canExecute: false,
                reason: "Minimum işlem tutarı: \(minTradeAmount)",
                adjustedQuantity: nil
            )
        }
        
        // 2. Likidite kontrolü
        let maxValue = maxOrderSize(dailyVolume: dailyVolume, price: price)
        if orderValue > maxValue && maxValue > 0 {
            let adjustedQty = maxValue / price
            return ExecutionValidation(
                canExecute: true,
                reason: "Likidite kısıtı: Maksimum \(Int(adjustedQty)) adet",
                adjustedQuantity: adjustedQty
            )
        }
        
        return ExecutionValidation(canExecute: true, reason: nil, adjustedQuantity: nil)
    }
    
    // MARK: - Simulation Methods
    
    /// Alış simülasyonu
    func simulateBuy(price: Double, quantity: Double, dailyVolume: Double = 1_000_000) -> ExecutionResult {
        let orderValue = price * quantity
        
        // Likidite kontrolü
        let validation = canExecute(orderValue: orderValue, dailyVolume: dailyVolume, price: price)
        let effectiveQty = validation.adjustedQuantity ?? quantity
        
        // Fiyat hesaplama
        let executedPrice = calculateBuyPrice(marketPrice: price)
        let tradeValue = executedPrice * effectiveQty
        let commission = calculateCommission(tradeValue: tradeValue)
        let slippage = (executedPrice - price) * effectiveQty
        
        return ExecutionResult(
            requestedPrice: price,
            executedPrice: executedPrice,
            slippage: slippage,
            commission: commission,
            totalCost: slippage + commission,
            quantity: effectiveQty,
            netValue: tradeValue + commission,
            timestamp: Date()
        )
    }
    
    /// Satış simülasyonu
    func simulateSell(price: Double, quantity: Double, dailyVolume: Double = 1_000_000) -> ExecutionResult {
        let orderValue = price * quantity
        
        // Likidite kontrolü
        let validation = canExecute(orderValue: orderValue, dailyVolume: dailyVolume, price: price)
        let effectiveQty = validation.adjustedQuantity ?? quantity
        
        // Fiyat hesaplama
        let executedPrice = calculateSellPrice(marketPrice: price)
        let tradeValue = executedPrice * effectiveQty
        let commission = calculateCommission(tradeValue: tradeValue)
        let slippage = (price - executedPrice) * effectiveQty
        
        return ExecutionResult(
            requestedPrice: price,
            executedPrice: executedPrice,
            slippage: slippage,
            commission: commission,
            totalCost: slippage + commission,
            quantity: effectiveQty,
            netValue: tradeValue - commission,
            timestamp: Date()
        )
    }
}

// MARK: - Execution Validation Result

struct ExecutionValidation: Sendable {
    let canExecute: Bool
    let reason: String?
    let adjustedQuantity: Double?
}

// MARK: - Execution Result

struct ExecutionResult: Codable, Sendable {
    let requestedPrice: Double
    let executedPrice: Double
    let slippage: Double
    let commission: Double
    let totalCost: Double
    let quantity: Double
    let netValue: Double       // Gerçek değer (komisyon düşülmüş)
    let timestamp: Date
    
    var slippagePct: Double {
        abs(executedPrice - requestedPrice) / requestedPrice * 100.0
    }
}

// MARK: - Backtest Integration Helper

extension ExecutionModel {
    /// Backtest için basitleştirilmiş maliyet hesabı
    func adjustedReturn(grossReturn: Double, tradeCount: Int, avgTradeValue: Double) -> Double {
        let totalCommission = Double(tradeCount) * (fixedCommission + avgTradeValue * commissionPct / 100.0)
        let totalSlippage = Double(tradeCount) * avgTradeValue * slippagePct / 100.0
        return grossReturn - totalCommission - totalSlippage
    }
    
    /// Net PnL hesapla
    func calculateNetPnL(
        entryPrice: Double,
        exitPrice: Double,
        quantity: Double
    ) -> Double {
        // Entry cost
        let buyPrice = calculateBuyPrice(marketPrice: entryPrice)
        let buyCommission = calculateCommission(tradeValue: buyPrice * quantity)
        
        // Exit cost
        let sellPrice = calculateSellPrice(marketPrice: exitPrice)
        let sellCommission = calculateCommission(tradeValue: sellPrice * quantity)
        
        // Net PnL
        let grossPnL = (sellPrice - buyPrice) * quantity
        return grossPnL - buyCommission - sellCommission
    }
}

