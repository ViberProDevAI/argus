import Foundation

enum BacktestAction: Equatable {
    case buy
    case sell(Double) // Percentage to sell (1.0 = All, 0.5 = Half)
    case hold
}

// Restore legacy TradeAction for TradingViewModel compatibility
// TradeAction moved to BacktestModels.swift

actor ArgusBacktestEngine {
    static let shared = ArgusBacktestEngine()
    
    private init() {}
    
    /// Runs a simulation based on provided configuration and historical data.
    func runBacktest(
        symbol: String,
        config: BacktestConfig,
        candles: [Candle],
        financials: FinancialsData?
    ) -> BacktestResult {
        return runDetailedBacktest(symbol: symbol, candles: candles, config: config, financials: financials)
    }
    
    func runDetailedBacktest(
        symbol: String,
        candles: [Candle],
        config: BacktestConfig = BacktestConfig(),
        financials: FinancialsData? = nil
    ) -> BacktestResult {
        
        var currentCapital = config.initialCapital
        var shares = 0.0
        var trades: [BacktestTrade] = []
        var equityCurve: [EquityPoint] = []
        var logs: [BacktestDayLog] = []
        var activeTrade: BacktestTrade?
        
        var maxEq: Double = config.initialCapital
        var maxDrawdown: Double = 0.0
        
        // Data Check
        let startIndex: Int
        if candles.count > 205 { startIndex = 200 }
        else if candles.count > 60 { startIndex = 55 }
        else { startIndex = 0 }
        
        if startIndex == 0 && candles.count < 14 { // Minimal check
             return BacktestResult(
                symbol: symbol, config: config, finalCapital: currentCapital, totalReturn: 0,
                trades: [], winRate: 0, candles: candles, maxDrawdown: 0, equityCurve: [], logs: []
            )
        }
        
        // --- PRE-CALCULATE INDICATORS (OPTIMIZATION) ---
        let prices = candles.map { $0.close }
        var rsiValues: [Double?] = []
        var sma50Values: [Double?] = []
        var sma200Values: [Double?] = []
        var bbValues: (upper: [Double?], middle: [Double?], lower: [Double?]) = ([], [], [])
        var sarValues: [Double?] = []
        
        switch config.strategy {
        case .rsiMeanReversion:
            rsiValues = IndicatorService.calculateRSI(values: prices)
        case .goldenCross:
            sma50Values = IndicatorService.calculateSMA(values: prices, period: 50)
            sma200Values = IndicatorService.calculateSMA(values: prices, period: 200)
        case .bollingerBreakout:
            bbValues = IndicatorService.calculateBollingerBands(values: prices)
        case .sarTrend:
            sarValues = IndicatorService.calculateSAR(candles: candles)
        default: break
        }
        // ----------------------------------------------
        
        // MAIN LOOP
        for i in startIndex..<candles.count {
            let slice = Array(candles.prefix(i + 1))
            let candle = candles[i]
            let price = candle.close
            var exitPriceOverride: Double? = nil
            
            var action: BacktestAction = .hold
            var reason = ""
            var logDetails = ""
            var usedScore = 50.0 // Neutral default
            
            // STRATEGY LOGIC
            switch config.strategy {
            // ARGUS AI STRATEGIES
            case .argusStandard, .aggressive, .conservative:
                 // 1. Dynamic Orion
                guard let orionResult = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: slice) else { continue }
                let trendPct = (orionResult.components.trend / 30.0) * 100.0
                let dailyAether = trendPct
                
                // 2. Decision
                let decision = ArgusDecisionEngine.shared.makeDecision(
                    symbol: symbol,
                    assetType: .stock,
                    atlas: nil,
                    orion: orionResult.score,
                    orionDetails: orionResult,
                    aether: dailyAether,
                    hermes: nil,
                // cronos: nil, REMOVED
                    athena: nil,
                    phoenixAdvice: nil,
                    demeterScore: nil,
                    marketData: nil
                ).1 // Take Decision Result
                
                usedScore = (config.strategy == .conservative) ? decision.finalScoreCore : decision.finalScorePulse
                let rawAction = (config.strategy == .conservative) ? decision.finalActionCore : decision.finalActionPulse
                
                // Map SignalAction to BacktestAction
                switch rawAction {
                case .buy: action = .buy
                case .sell: action = .sell(1.0)
                default: action = .hold
                }
                
                // BACKTEST SIMULATION: AUTO-PILOT "MOMENTUM DECAY" Override
                // Mirrors logic in ArgusAutoPilotEngine.swift
                if let trade = activeTrade, config.strategy != .conservative {
                    let pnl = ((price - trade.entryPrice) / trade.entryPrice) * 100.0
                    // If Profit > 2% AND Score drops below 62 (Momentum Fading) -> SELL
                    if pnl > 2.0 && usedScore < 62.0 {
                        action = .sell(1.0)
                        reason = "Pulse Exit (Decay: \(Int(usedScore)))"
                    }
                }
                
                if case .sell = action, reason == "" { reason = "Argus Signal" }
                else if action == .buy && reason == "" { reason = "Argus Signal" }
                
                logDetails = "O:\(String(format:"%.0f", orionResult.score)) Aes:\(String(format:"%.0f", dailyAether))"

            case .orionV2:
                // ORION V2 PURE TECH STRATEGY (Improved Entry/Exit Logic)
                guard let orionResult = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: slice) else { continue }
                usedScore = orionResult.score
                
                // Calculate simple trend indicators for backup logic
                let recentSlice = Array(slice.suffix(20))
                let recentHigh = recentSlice.map(\.high).max() ?? price
                let recentLow = recentSlice.map(\.low).min() ?? price
                let trendRange = recentHigh - recentLow
                let pullbackDepth = trendRange > 0 ? (recentHigh - price) / trendRange : 0
                
                // Check if trend is up (price above 50% of range)
                let isTrending = price > (recentLow + trendRange * 0.5)
                
                // Simple momentum: are we making higher lows?
                let last5Lows = Array(slice.suffix(5)).map(\.low)
                let prev5Lows = Array(slice.dropLast(5).suffix(5)).map(\.low)
                let isHigherLows = (last5Lows.min() ?? 0) > (prev5Lows.min() ?? 0)
                
                logDetails = "O2: \(Int(usedScore)) T:\(isTrending ? "↑" : "↓")"
                
                // ===== ENTRY CONDITIONS (Relaxed for more trades) =====
                if shares == 0 {
                    // 1. Strong Orion Score (Primary) - Relaxed significantly for V2
                    // V2 scores are structurally lower/stricter, so we lower threshold to 42-45 range
                    if usedScore >= 42 {
                        action = .buy
                        reason = "Orion Makul (V2 \(Int(usedScore)))"
                    }
                    // 2. Trend Confirmation Entry (Lower score ok if trending strongly)
                    else if usedScore >= 38 && isTrending && isHigherLows {
                        action = .buy
                        reason = "Trend + Momentum (\(Int(usedScore)))"
                    }
                    // 3. Pullback Entry in Uptrend - Lowered from 50
                    else if usedScore >= 45 && isTrending && pullbackDepth > 0.25 && pullbackDepth < 0.65 {
                        action = .buy
                        reason = "Pullback Entry"
                    }
                    // 4. Periodic Re-entry in Strong Trend - Lowered from 45
                    else if usedScore >= 40 && isTrending && i % 20 == 0 {
                        action = .buy
                        reason = "Trend Devam"
                    }
                }
                
                // ===== EXIT CONDITIONS (Optimized to avoid many small wins / few big losses) =====
                else if shares > 0 {
                    // Get entry price for P&L calculation
                    let entryPrice = activeTrade?.entryPrice ?? price
                    let pnlPct = ((price - entryPrice) / entryPrice) * 100.0
                    
                    // Track highest price since entry for trailing stop logic
                    let highSinceEntry = slice.suffix(20).map(\.high).max() ?? price
                    let drawdownFromHigh = ((highSinceEntry - price) / highSinceEntry) * 100.0
                    
                    // === STOP LOSS (Always Full Exit) ===
                    // 1. Hard Stop: -8% loss = Full Exit (protect capital)
                    if pnlPct < -8.0 {
                        action = .sell(1.0)
                        reason = "Stop Loss (-8%)"
                    }
                    // 2. Critical Score Drop: Trend completely broken
                    else if usedScore < 30 {
                        action = .sell(1.0)
                        reason = "Trend Bitti (<30)"
                    }
                    
                    // === PROFIT TAKING (Aggressive) ===
                    // 3. Big Win: +25% = Take 70% profit (leave 30% for trend riding)
                    else if pnlPct > 25 {
                        action = .sell(0.70)
                        reason = "Kâr Al (+25%)"
                    }
                    // 4. Trailing Stop: In profit but pulling back from high
                    else if pnlPct > 10 && drawdownFromHigh > 5.0 {
                        action = .sell(1.0)  // Full exit - protect profits
                        reason = "Trailing Stop"
                    }
                    // 5. Medium Win + Score Decay = Full Exit (don't let winners turn to losers)
                    else if pnlPct > 8 && usedScore < 45 {
                        action = .sell(1.0)
                        reason = "Kâr Koru (+8%)"
                    }
                    
                    // === TREND BREAK (Conservative) ===
                    // 6. Trend broken + small profit = exit
                    else if !isTrending && pnlPct > 3 {
                        action = .sell(1.0)
                        reason = "Trend Kırıldı"
                    }
                    // 7. Trend broken + losing = cut losses
                    else if !isTrending && pnlPct < 0 && usedScore < 40 {
                        action = .sell(1.0)
                        reason = "Zarar Kes"
                    }
                }


            // CLASSIC TA STRATEGIES
            case .buyAndHold:
                if i == startIndex { action = .buy; reason = "Start" }
                logDetails = "Buy & Hold"
                
            case .rsiMeanReversion:
                if let val = rsiValues[i] {
                    usedScore = val
                    logDetails = "RSI: \(String(format: "%.1f", val))"
                    if val < 30 { action = .buy; reason = "RSI Oversold" }
                    else if val > 70 { action = .sell(1.0); reason = "RSI Overbought" }
                }
                
            case .goldenCross:
                if let s50 = sma50Values[i], let s200 = sma200Values[i] {
                    usedScore = 50.0 // No granular score
                    logDetails = "50/200: \(String(format: "%.1f", s50))/\(String(format: "%.1f", s200))"
                    if s50 > s200 { action = .buy; reason = "Golden Cross" }
                    else { action = .sell(1.0); reason = "Death Cross" }
                }
                
            case .bollingerBreakout:
                if let lower = bbValues.lower[i], let upper = bbValues.upper[i] {
                    logDetails = "L/U: \(String(format: "%.1f", lower))/\(String(format: "%.1f", upper))"
                    if price < lower { action = .buy; reason = "Band Low Break" }
                    // Sell on mean reversion (middle) or upper break? Standard breakout usually plays trend.
                    // Let's implement "Reversion": Buy Low, Sell High.
                    else if price > upper { action = .sell(1.0); reason = "Band High Break" }
                }
                
            case .sarTrend:
                if let s = sarValues[i] {
                    logDetails = "SAR: \(String(format: "%.1f", s))"
                    if price > s { action = .buy; reason = "Trend Up" }
                    else { action = .sell(1.0); reason = "Trend Down" }
                }
                
            case .phoenixChannel:
                // Phoenix Channel Logic - Enhanced for Trend Following
                let lookback = 50 // Reduced for more frequent signals
                if i > lookback {
                    let slice = Array(candles.prefix(i + 1))
                    let phoenixConfig = PhoenixConfig()
                    
                    let advice = PhoenixLogic.analyze(
                        candles: slice,
                        symbol: symbol,
                        timeframe: .auto,
                        config: phoenixConfig
                    )
                    
                    usedScore = advice.confidence
                    logDetails = "Phx: \(Int(advice.confidence)) T:\(advice.triggers.trendOk ? "✓" : "✗")"
                    
                    // Calculate recent trend (last 20 bars)
                    let recentSlice = Array(slice.suffix(20))
                    let recentHigh = recentSlice.map(\.high).max() ?? price
                    let recentLow = recentSlice.map(\.low).min() ?? price
                    let trendRange = recentHigh - recentLow
                    let pullbackDepth = (recentHigh - price) / max(trendRange, 0.01)
                    let isInUptrend = advice.triggers.trendOk && price > (recentLow + trendRange * 0.5)
                    
                    // ===== ENTRY CONDITIONS =====
                    if shares == 0 {
                        // 1. High Confidence Entry
                        if advice.confidence >= 50 {
                            action = .buy
                            reason = "Güçlü Sinyal (\(Int(advice.confidence)))"
                        }
                        // 2. Channel Touch Entry
                        else if advice.triggers.touchLowerBand {
                            action = .buy
                            reason = "Kanal Teması"
                        }
                        // 3. Divergence Entry
                        else if advice.triggers.bullishDivergence {
                            action = .buy
                            reason = "Pozitif Uyumsuzluk"
                        }
                        // 4. RSI Reversal Entry
                        else if advice.triggers.rsiReversal && advice.triggers.trendOk {
                            action = .buy
                            reason = "RSI Dönüşü"
                        }
                        // 5. NEW: Pullback Entry in Uptrend
                        else if isInUptrend && pullbackDepth > 0.3 && pullbackDepth < 0.6 {
                            action = .buy
                            reason = "Trend Pullback"
                        }
                        // 6. NEW: Trend Continuation (periodic re-entry)
                        else if isInUptrend && advice.confidence >= 40 && i % 30 == 0 {
                            // Re-enter every ~30 bars if trend is intact
                            action = .buy
                            reason = "Trend Devam"
                        }
                    }
                    
                    // ===== EXIT CONDITIONS =====
                    if shares > 0 {
                        // 1. Profit Target (channel upper or 15%+)
                        if let upper = advice.channelUpper, price > upper {
                            action = .sell(0.5) // Partial - keep riding trend
                            reason = "Üst Bant Teması"
                        }
                        // 2. Strong Profit - Take half
                        else if let entryP = activeTrade?.entryPrice, price > entryP * 1.15 {
                            action = .sell(0.5)
                            reason = "Kâr Al (+15%)"
                        }
                        // 3. Invalidation Stop
                        else if let inv = advice.invalidationLevel, price < inv {
                            action = .sell(1.0)
                            reason = "İhlal Stop"
                        }
                        // 4. Confidence Collapse
                        else if advice.confidence < 25 {
                            action = .sell(1.0)
                            reason = "Sinyal Zayıfladı"
                        }
                        // 5. Trend Break - partial exit
                        else if !advice.triggers.trendOk && advice.confidence < 40 {
                            action = .sell(0.5)
                            reason = "Trend Kırıldı"
                        }
                    }
                }
            }
            
            // FORCE STOP LOSS CHECK (Global) - DISABLED for orionV2 (uses tiered exit)
            // Only apply to strategies without built-in exit logic
            if config.strategy != .orionV2 {
                if let trade = activeTrade {
                    let stopPrice = trade.entryPrice * (1.0 - config.stopLossPct)
                    if candle.open < stopPrice {
                        action = .sell(1.0)
                        reason = "Gap Stop"
                        exitPriceOverride = candle.open
                    } else if candle.low <= stopPrice {
                        action = .sell(1.0)
                        reason = "Stop Loss"
                        exitPriceOverride = stopPrice
                    }
                }
            }
            
            // LOGGING
            var actionString = "HOLD"
            if action == .buy { actionString = "BUY" }
            if case .sell(_) = action { actionString = "SELL" }
            
            logs.append(BacktestDayLog(
                date: candle.date,
                price: exitPriceOverride ?? price,
                score: usedScore,
                action: actionString,
                details: logDetails
            ))
            
            // EXECUTION (Updated for Partial + Transaction Costs)
            let execModel = config.executionModel

            if action == .buy && shares == 0 {
                // Slippage uygula (alım fiyatını artır)
                let executionPrice = execModel.calculateBuyPrice(marketPrice: price)
                let availableForTrade = currentCapital * 0.99
                let commission = execModel.calculateCommission(tradeValue: availableForTrade)
                let netAvailable = availableForTrade - commission
                let qty = netAvailable / executionPrice

                shares = qty
                currentCapital -= (qty * executionPrice + commission)
                activeTrade = BacktestTrade(
                    entryDate: candle.date,
                    exitDate: Date.distantFuture,
                    entryPrice: executionPrice,
                    exitPrice: 0,
                    quantity: qty,
                    type: .long,
                    exitReason: ""
                )
            }
            else if case .sell(let pct) = action, shares > 0, let trade = activeTrade {
                let basePrice = exitPriceOverride ?? price
                // Slippage uygula (satış fiyatını düşür)
                let sellPrice = execModel.calculateSellPrice(marketPrice: basePrice)
                let qtyToSell = shares * pct
                let grossRevenue = qtyToSell * sellPrice
                let commission = execModel.calculateCommission(tradeValue: grossRevenue)
                let netRevenue = grossRevenue - commission

                // Update Portfolio
                currentCapital += netRevenue
                shares -= qtyToSell
                
                // Log Completed Segment
                let completed = BacktestTrade(
                    entryDate: trade.entryDate,
                    exitDate: candle.date,
                    entryPrice: trade.entryPrice, // Keep original entry price base
                    exitPrice: sellPrice,
                    quantity: qtyToSell,
                    type: .long,
                    exitReason: reason
                )
                trades.append(completed)
                
                // Update Active Trade State
                if shares < 0.000001 { // If remaining shares are negligible
                    activeTrade = nil
                    shares = 0
                } else {
                    // Update remaining quantity in active trade record
                    activeTrade = BacktestTrade(
                        entryDate: trade.entryDate,
                        exitDate: trade.exitDate,
                        entryPrice: trade.entryPrice,
                        exitPrice: trade.exitPrice,
                        quantity: shares, // NEW QUANTITY
                        type: trade.type,
                        exitReason: trade.exitReason
                    )
                }
            }
            
            // EQUITY
            let equity = currentCapital + (shares > 0 ? shares * price : 0)
            equityCurve.append(EquityPoint(date: candle.date, value: equity))
            if equity > maxEq { maxEq = equity }
            let dd = (maxEq - equity) / maxEq * 100.0
            if dd > maxDrawdown { maxDrawdown = dd }
        }
        
        // Close end position
        if shares > 0, let trade = activeTrade {
           let finalPrice = candles.last!.close
           currentCapital += shares * finalPrice
           let completed = BacktestTrade(
               entryDate: trade.entryDate,
               exitDate: candles.last!.date,
               entryPrice: trade.entryPrice,
               exitPrice: finalPrice,
               quantity: trade.quantity,
               type: .long,
               exitReason: "End"
           )
           trades.append(completed)
        }
        
        let totalRet = ((currentCapital - config.initialCapital) / config.initialCapital) * 100.0
        let wins = trades.filter { $0.pnl > 0 }.count
        let winRate = trades.isEmpty ? 0 : (Double(wins) / Double(trades.count)) * 100.0
        
        return BacktestResult(
            symbol: symbol,
            config: config,
            finalCapital: currentCapital,
            totalReturn: totalRet,
            trades: trades,
            winRate: winRate,
            candles: candles, // Layout: Candles passed for visualization
            maxDrawdown: maxDrawdown,
            equityCurve: equityCurve,
            logs: logs
        )
    }
}
