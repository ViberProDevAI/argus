import Foundation

class OrionStatsEngine {
    
    /// Computes performance statistics for Orion snapshots.
    /// Computes performance statistics for Orion snapshots.
    /// - Parameters:
    ///   - snapshots: List of snapshots to analyze.
    /// - Returns: A list of stats grouped by Letter Grade.
    func computeStats(snapshots: [OrionSnapshot]) async -> [OrionGradeStats] {
        // 1. Group by Letter Grade
        let grouped = Dictionary(grouping: snapshots, by: { $0.orionLetter })
        
        var statsList: [OrionGradeStats] = []
        
        // Define desired grades order for consistent processing (optional, but good for debugging)
        let allGrades = grouped.keys.sorted()
        
        for letter in allGrades {
            guard let gradeSnapshots = grouped[letter] else { continue }
            
            var returns1D: [Double] = []
            var returns5D: [Double] = []
            var returns20D: [Double] = []
            var hits5D: Int = 0
            var count5D: Int = 0
            
            // Process each snapshot in parallel or sequence
            // Since we need to fetch candles, we might want to batch this or do it per symbol.
            // Optimization: Fetch full history for a symbol once, then lookup dates.
            
            // Group snapshots by symbol to minimize API calls
            let symbolGroups = Dictionary(grouping: gradeSnapshots, by: { $0.symbol })
            
            // Parallel Fetching using TaskGroup
            await withTaskGroup(of: (String, [Candle]?).self) { group in
                for (symbol, _) in symbolGroups {
                    group.addTask {
                        // Try to fetch candles for this symbol
                        // Fixed: Use HeimdallOrchestrator and standard "1day" timeframe
                        let candles = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1day", limit: 365)
                        return (symbol, candles)
                    }
                }
                
                // Collect results
                var candlesMap: [String: [Candle]] = [:]
                for await (symbol, candles) in group {
                    if let c = candles {
                        candlesMap[symbol] = c
                    }
                }
                
                // Process snapshots with fetched candles
                for (symbol, symSnapshots) in symbolGroups {
                    if let candles = candlesMap[symbol] {
                        for snapshot in symSnapshots {
                            if let (r1, r5, r20) = self.calculateReturns(snapshot: snapshot, candles: candles) {
                                if let r1 = r1 { returns1D.append(r1) }
                                if let r5 = r5 {
                                    returns5D.append(r5)
                                    count5D += 1
                                    if r5 > 0 { hits5D += 1 }
                                }
                                if let r20 = r20 { returns20D.append(r20) }
                            }
                        }
                    }
                }
            }
            
            // Calculate Averages
            let avg1D = returns1D.isEmpty ? nil : returns1D.reduce(0, +) / Double(returns1D.count)
            let avg5D = returns5D.isEmpty ? nil : returns5D.reduce(0, +) / Double(returns5D.count)
            let avg20D = returns20D.isEmpty ? nil : returns20D.reduce(0, +) / Double(returns20D.count)
            
            let hitRate = count5D > 0 ? (Double(hits5D) / Double(count5D)) * 100.0 : nil
            
            let stat = OrionGradeStats(
                letter: letter,
                count: gradeSnapshots.count,
                avgReturn1D: avg1D,
                avgReturn5D: avg5D,
                avgReturn20D: avg20D,
                hitRate5D: hitRate
            )
            statsList.append(stat)
        }
        
        // Sort by Grade (A+ -> F)
        return statsList.sorted { gradeRank($0.letter) < gradeRank($1.letter) }
    }
    
    // MARK: - Helpers
    
    private func calculateReturns(snapshot: OrionSnapshot, candles: [Candle]) -> (Double?, Double?, Double?)? {
        // Find the candle corresponding to snapshot date
        // Since snapshot.date includes time, we compare by day.
        let calendar = Calendar.current
        
        guard let startIndex = candles.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: snapshot.date) }) else {
            // Snapshot date not found in candles (maybe weekend or holiday or too old/new)
            return nil
        }
        
        let startPrice = candles[startIndex].close // Using Close price of the signal day
        // Alternatively, use snapshot.price if it's more accurate for entry
        // let startPrice = snapshot.price
        
        func getReturn(days: Int) -> Double? {
            let targetIndex = startIndex + days
            if targetIndex < candles.count {
                let endPrice = candles[targetIndex].close
                return ((endPrice - startPrice) / startPrice) * 100.0
            }
            return nil
        }
        
        return (getReturn(days: 1), getReturn(days: 5), getReturn(days: 20))
    }
    
    private func gradeRank(_ letter: String) -> Int {
        switch letter {
        case "A+": return 0
        case "A": return 1
        case "A-": return 2
        case "B+": return 3
        case "B": return 4
        case "B-": return 5
        case "C+": return 6
        case "C": return 7
        case "C-": return 8
        case "D": return 9
        case "F": return 10
        default: return 99
        }
    }
}
