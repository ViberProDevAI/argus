import Foundation

// MARK: - Strategy Types
enum StrategyType: String, CaseIterable, Identifiable {
    case sma = "SMA Crossover"
    case rsi = "RSI Mean Reversion"
    case macd = "MACD Trend"
    case bollinger = "Bollinger Bands"
    case stochastic = "Stochastic"
    case cci = "CCI Trend"
    
    var id: String { rawValue }
}

// MARK: - Strategy Result
struct StrategyResult: Identifiable {
    let id = UUID()
    let strategyName: String
    let totalReturn: Double // %
    let maxDrawdown: Double // %
    let tradeCount: Int
    let winRate: Double // %
    let score: Double // 0-100
    let currentAction: SignalAction // BUY, SELL, HOLD
    
    var summary: String {
        return String(format: "Getiri: %% %.1f | Max DD: %% %.1f | Win: %% %.0f", totalReturn, maxDrawdown, winRate)
    }
}

// MARK: - Strategy Protocol
protocol Strategy: Sendable {
    var name: String { get }
    func backtest(candles: [Candle]) -> StrategyResult
}

// MARK: - 1. RSI Mean Reversion
struct RSIStrategy: Strategy {
    let name = "RSI Mean Reversion (14)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let closes = candles.map { $0.close }
        let rsiValues = IndicatorService.calculateRSI(values: closes, period: 14)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = [] // Profit/Loss % per trade
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        
        // Sinyal tespiti için son durum
        var currentAction: SignalAction = .hold
        
        for i in 15..<candles.count {
            guard let currentRSI = rsiValues[i], let prevRSI = rsiValues[i-1] else { continue }
            let price = closes[i]
            
            // AL: RSI 30'u yukarı kesti
            if !inPosition && prevRSI < 30 && currentRSI >= 30 {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: RSI 60'ı aşağı kesti
            else if inPosition && prevRSI > 60 && currentRSI <= 60 {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        // Eğer pozisyondaysak ve sat sinyali gelmediyse, şu anki durum HOLD (veya "Pozisyonda")
        // Ancak kullanıcı "Al/Sat" sinyali istiyor.
        // Eğer son bar itibariyle AL koşulu oluştuysa BUY dedik.
        // Eğer pozisyondaysak ve henüz sat gelmediyse buna HOLD diyebiliriz veya "Taşı" diyebiliriz.
        // Basitlik için: Son barda işlem olduysa onu döndür, yoksa HOLD.
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}

// MARK: - 2. MACD Trend Following
struct MACDStrategy: Strategy {
    let name = "MACD Trend (12, 26, 9)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let closes = candles.map { $0.close }
        let (macd, signal, _) = IndicatorService.calculateMACD(values: closes)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        for i in 30..<candles.count {
            guard let currMacd = macd[i], let currSig = signal[i],
                  let prevMacd = macd[i-1], let prevSig = signal[i-1] else { continue }
            
            let price = closes[i]
            
            // AL: MACD Signal'i yukarı kesti
            if !inPosition && prevMacd < prevSig && currMacd > currSig {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: MACD Signal'i aşağı kesti
            else if inPosition && prevMacd > prevSig && currMacd < currSig {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}

// MARK: - 3. SMA Crossover
struct SMACrossoverStrategy: Strategy {
    let name = "SMA Crossover (20/50)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let closes = candles.map { $0.close }
        let sma20 = IndicatorService.calculateSMA(values: closes, period: 20)
        let sma50 = IndicatorService.calculateSMA(values: closes, period: 50)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        for i in 51..<candles.count {
            guard let s20 = sma20[i], let s50 = sma50[i],
                  let prevS20 = sma20[i-1], let prevS50 = sma50[i-1] else { continue }
            
            let price = closes[i]
            
            // AL: SMA20, SMA50'yi yukarı kesti
            if !inPosition && prevS20 < prevS50 && s20 > s50 {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: SMA20, SMA50'yi aşağı kesti
            else if inPosition && prevS20 > prevS50 && s20 < s50 {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}

// MARK: - 4. Bollinger Bands
struct BollingerStrategy: Strategy {
    let name = "Bollinger Bands (20, 2)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let closes = candles.map { $0.close }
        let (_, middle, lower) = IndicatorService.calculateBollingerBands(values: closes)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        for i in 20..<candles.count {
            guard let low = lower[i], let mid = middle[i] else { continue }
            
            let price = closes[i]
            
            // AL: Fiyat alt banda değdi veya altına indi
            if !inPosition && price <= low {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: Fiyat orta banda (SMA20) geldi
            else if inPosition && price >= mid {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}
// MARK: - 5. Stochastic Oscillator Strategy
struct StochasticStrategy: Strategy {
    let name = "Stochastic (14, 3, 3)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let (kValues, dValues) = IndicatorService.calculateStochastic(candles: candles)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        for i in 15..<candles.count {
            guard let k = kValues[i], let d = dValues[i],
                  let prevK = kValues[i-1], let prevD = dValues[i-1] else { continue }
            
            let price = candles[i].close
            
            // AL: %K, %D'yi aşağıdan yukarı kesti ve Aşırı Satım (<20) bölgesinde
            if !inPosition && prevK < prevD && k > d && k < 20 {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: %K, %D'yi yukarıdan aşağı kesti ve Aşırı Alım (>80) bölgesinde
            else if inPosition && prevK > prevD && k < d && k > 80 {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}

// MARK: - 6. CCI Strategy
struct CCIStrategy: Strategy {
    let name = "CCI Trend (20)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        let cciValues = IndicatorService.calculateCCI(candles: candles)
        
        var inPosition = false
        var entryPrice = 0.0
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        for i in 21..<candles.count {
            guard let cci = cciValues[i], let prevCCI = cciValues[i-1] else { continue }
            
            let price = candles[i].close
            
            // AL: CCI -100'ü yukarı kesti (Aşırı satımdan dönüş)
            if !inPosition && prevCCI < -100 && cci > -100 {
                inPosition = true
                entryPrice = price
                if i == candles.count - 1 { currentAction = .buy }
            }
            // SAT: CCI +100'ü aşağı kesti (Aşırı alımdan dönüş)
            else if inPosition && prevCCI > 100 && cci < 100 {
                inPosition = false
                let profitPct = ((price - entryPrice) / entryPrice) * 100
                trades.append(profitPct)
                
                let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                equityCurve.append(newEquity)
                
                if newEquity > maxEquity { maxEquity = newEquity }
                let dd = (maxEquity - newEquity) / maxEquity * 100
                if dd > maxDrawdown { maxDrawdown = dd }
                
                if i == candles.count - 1 { currentAction = .sell }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}
// MARK: - 7. Orion Strategy (The Brain)
struct OrionStrategy: Strategy {
    let name = "Orion Strategy (v2.1)"
    
    func backtest(candles: [Candle]) -> StrategyResult {
        // Optimization: Pre-calculate basic indicators
        
        var inPosition = false
        var entryPrice = 0.0
        var maxTradeHigh = 0.0 // Trailing Stop Tracker
        var trades: [Double] = []
        var equityCurve: [Double] = [10000.0]
        var maxEquity = 10000.0
        var maxDrawdown = 0.0
        var currentAction: SignalAction = .hold
        
        // Orion needs at least ~60 candles
        guard candles.count > 60 else {
            return calculateResult(name: name, trades: [], equityCurve: [10000], maxDrawdown: 0, currentAction: .hold)
        }
        
        for i in 60..<candles.count {
            // LOOK-AHEAD BIAS FIX: i HARİÇ - sadece geçmiş veriler kullanılır
            let window = Array(candles[(i-60)..<i])
            
            // Calculate Score
            // Calculate Score
            // Use dummy symbol since Protocol doesn't provide it, and calculation is symbol-agnostic
            let analysisOpt = OrionAnalysisService.shared.calculateOrionScore(symbol: "BACKTEST", candles: window, spyCandles: nil)
            guard let analysis = analysisOpt else { continue }
            
            let score = analysis.score
            let trendScore = analysis.components.trend // 0-30 scale
            let isDip = false // Phoenix Removed
            
            let price = candles[i].close
            
            // BUY RULES (Stricter):
            // 1. Strong Score (>= 70) AND Strong Trend (>= 18)
            // 2. OR Dip Hunter Trigger
            let isBuySignal = (score >= 70 && trendScore >= 18) || (isDip)
            
            // SELL RULES:
            // 1. Trend Broken (Score < 35)
            let isTrendBroken = (score < 35)
            
            // Execution
            if !inPosition && isBuySignal {
                inPosition = true
                entryPrice = price
                maxTradeHigh = price // Init Tracker
                if i == candles.count - 1 { currentAction = .buy }
            }
            else if inPosition {
                // Update Trailing High
                if price > maxTradeHigh { maxTradeHigh = price }
                
                // Trailing Stop Calc (12%)
                let trailingDrop = (maxTradeHigh - price) / maxTradeHigh
                let isTrailingHit = trailingDrop > 0.12
                
                let pnl = (price - entryPrice) / entryPrice
                
                // Exit Rules: Trend Broken OR Stop (Hard 5%) OR Trailing Stop
                if isTrendBroken || pnl < -0.05 || isTrailingHit {
                    inPosition = false
                    let profitPct = pnl * 100
                    trades.append(profitPct)
                    
                    let newEquity = (equityCurve.last ?? 10000.0) * (1 + profitPct/100)
                    equityCurve.append(newEquity)
                    
                    if newEquity > maxEquity { maxEquity = newEquity }
                    let dd = (maxEquity - newEquity) / maxEquity * 100
                    if dd > maxDrawdown { maxDrawdown = dd }
                    
                    // Reset
                    maxTradeHigh = 0.0
                    
                    if i == candles.count - 1 { currentAction = .sell }
                }
            }
        }
        
        return calculateResult(name: name, trades: trades, equityCurve: equityCurve, maxDrawdown: maxDrawdown, currentAction: currentAction)
    }
}

// MARK: - Helper
func calculateResult(name: String, trades: [Double], equityCurve: [Double], maxDrawdown: Double, currentAction: SignalAction) -> StrategyResult {
    let totalReturn = ((equityCurve.last ?? 10000) - 10000) / 10000 * 100
    let winCount = trades.filter { $0 > 0 }.count
    let winRate = trades.isEmpty ? 0 : (Double(winCount) / Double(trades.count)) * 100
    
    // --- YENİ SKORLAMA MANTIĞI (Kullanıcı İsteği) ---
    // Formül: 0.5 * Return + 0.3 * WinRate + 0.2 * Risk
    
    // 1. Normalize Return (0-100 arası)
    // %100 getiri = 100 puan kabul edelim (veya %50 = 100 puan, agresiflik seviyesine göre)
    // Kullanıcı "Yüksek totalReturn -> skoru artır" dedi.
    // %50 getiriye 100 puan verelim, üstü 100 kalsın.
    let normalizedReturn = min(max(totalReturn * 2, 0), 100)
    
    // 2. Normalize Win Rate (0-100 arası)
    // Zaten 0-100 geliyor.
    let normalizedWinRate = winRate
    
    // 3. Normalize Risk (1 - Drawdown)
    // MaxDD %0 ise 100 puan, %50 ise 0 puan.
    let normalizedRisk = max(0, 100 - (maxDrawdown * 2))
    
    // Ağırlıklı Skor
    var weightedScore = (normalizedReturn * 0.50) + (normalizedWinRate * 0.30) + (normalizedRisk * 0.20)
    
    // --- CEZALAR ---
    
    // 1. Düşük İşlem Sayısı Cezası
    if trades.count < 5 {
        weightedScore *= 0.5 // Ciddi düşür
    } else if trades.count < 10 {
        weightedScore *= 0.8 // Biraz düşür
    }
    
    // 2. Düşük Win Rate Cezası
    if winRate < 40 {
        weightedScore *= 0.6 // %40 altıysa ciddi düşür
    } else if winRate < 50 {
        weightedScore *= 0.8 // %50 altıysa biraz düşür
    }
    
    let finalScore = min(max(weightedScore, 0), 100)
    
    return StrategyResult(
        strategyName: name,
        totalReturn: totalReturn,
        maxDrawdown: maxDrawdown,
        tradeCount: trades.count,
        winRate: winRate,
        score: finalScore,
        currentAction: currentAction
    )
}
