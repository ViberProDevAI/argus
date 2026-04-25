import Foundation
import Combine

// MARK: - Fund Data Manager
// Manages fund data fetching, caching, and computation for the Fund Module

@MainActor
class FundDataManager: ObservableObject {
    static let shared = FundDataManager()
    
    // MARK: - Published State
    @Published var fundPrices: [String: FundPriceData] = [:]
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var lastRefresh: Date?
    
    // MARK: - Cache
    private var priceCache: [String: (data: [FundPrice], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    // MARK: - Sorting Options
    enum SortOption: String, CaseIterable {
        case return1Week = "1 Hafta"
        case return1Month = "1 Ay"
        case return1Year = "1 Yıl"
        case fundSize = "Büyüklük"
        case alphabetical = "A-Z"
    }
    
    private init() {}
    
    // MARK: - Load All Funds
    
    /// Loads price data for all funds in the watchlist
    func loadAllFunds() async {
        isLoading = true
        lastError = nil
        
        let codes = FundWatchlist.allCodes
        print("📊 FundDataManager: Starting to load \(codes.count) funds...")
        
        // Batch fetch in chunks - TEFAS rate limits aggressively
        let chunkSize = 3  // Reduced from 10 to avoid connection drops
        let chunks = stride(from: 0, to: codes.count, by: chunkSize).map {
            Array(codes[$0..<min($0 + chunkSize, codes.count)])
        }
        
        for (index, chunk) in chunks.enumerated() {
            print("📊 TEFAS Batch \(index + 1)/\(chunks.count): \(chunk.joined(separator: ", "))")
            
            await withTaskGroup(of: (String, FundPriceData?).self) { group in
                for code in chunk {
                    group.addTask {
                        do {
                            let priceData = try await self.fetchFundData(code: code)
                            return (code, priceData)
                        } catch {
                            print("❌ Fund fetch error for \(code): \(error.localizedDescription)")
                            return (code, nil)
                        }
                    }
                }
                
                for await (code, data) in group {
                    if let data = data {
                        fundPrices[code] = data
                        print("✅ Loaded: \(code) - Price: \(data.currentPrice)")
                    }
                }
            }
            
            // Longer delay between chunks to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        lastRefresh = Date()
        isLoading = false
        print("✅ FundDataManager: Loaded \(fundPrices.count)/\(codes.count) funds")
    }
    
    // MARK: - Fetch Single Fund
    
    /// Fetches price data for a single fund
    func fetchFundData(code: String) async throws -> FundPriceData {
        // Check cache first
        if let cached = priceCache[code],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL,
           !cached.data.isEmpty {
            return calculatePriceData(code: code, prices: cached.data)
        }
        
        // Fetch from TEFAS (FundTurkey API - max 60 günlük veri)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -60, to: endDate) ?? endDate
        
        let prices = try await TefasService.shared.fetchHistory(
            fundCode: code,
            startDate: startDate,
            endDate: endDate
        )
        
        // Cache the results
        priceCache[code] = (data: prices, timestamp: Date())
        
        return calculatePriceData(code: code, prices: prices)
    }
    
    // MARK: - Calculate Returns
    
    private func calculatePriceData(code: String, prices: [FundPrice]) -> FundPriceData {
        let sortedPrices = prices.sorted { $0.date > $1.date }
        
        guard let latest = sortedPrices.first else {
            return FundPriceData(code: code, currentPrice: 0)
        }
        
        let currentPrice = latest.price
        let previousPrice = sortedPrices.count > 1 ? sortedPrices[1].price : nil
        
        // Calculate returns for different periods
        let return1Week = calculateReturn(prices: sortedPrices, days: 7)
        let return1Month = calculateReturn(prices: sortedPrices, days: 30)
        let return3Month = calculateReturn(prices: sortedPrices, days: 90)
        let return6Month = calculateReturn(prices: sortedPrices, days: 180)
        let return1Year = calculateReturn(prices: sortedPrices, days: 365)
        let returnYTD = calculateYTDReturn(prices: sortedPrices)
        
        return FundPriceData(
            code: code,
            currentPrice: currentPrice,
            previousPrice: previousPrice,
            fundSize: latest.fundSize,
            investors: latest.investors,
            return1Week: return1Week,
            return1Month: return1Month,
            return3Month: return3Month,
            return6Month: return6Month,
            returnYTD: returnYTD,
            return1Year: return1Year
        )
    }
    
    private func calculateReturn(prices: [FundPrice], days: Int) -> Double? {
        guard let latest = prices.first else { return nil }
        
        let targetDate = Calendar.current.date(byAdding: .day, value: -days, to: latest.date) ?? latest.date
        
        // Find the price closest to the target date
        guard let oldPrice = prices.first(where: { $0.date <= targetDate }) else {
            return nil
        }
        
        guard oldPrice.price > 0 else { return nil }
        
        return ((latest.price - oldPrice.price) / oldPrice.price) * 100
    }
    
    private func calculateYTDReturn(prices: [FundPrice]) -> Double? {
        guard let latest = prices.first else { return nil }
        
        // Get start of current year
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return nil
        }
        
        // Find the first trading day of the year
        guard let ytdStart = prices.last(where: { $0.date >= startOfYear }) else {
            return nil
        }
        
        guard ytdStart.price > 0 else { return nil }
        
        return ((latest.price - ytdStart.price) / ytdStart.price) * 100
    }
    
    // MARK: - Sorting & Filtering
    
    /// Get sorted funds based on the selected option
    func sortedFunds(by option: SortOption, category: FundCategory? = nil) -> [FundListItem] {
        var funds = FundWatchlist.allFunds
        
        // Filter by category if specified
        if let category = category {
            funds = funds.filter { $0.category == category }
        }
        
        // Sort based on option
        switch option {
        case .return1Week:
            funds.sort { (fundPrices[$0.code]?.return1Week ?? -999) > (fundPrices[$1.code]?.return1Week ?? -999) }
        case .return1Month:
            funds.sort { (fundPrices[$0.code]?.return1Month ?? -999) > (fundPrices[$1.code]?.return1Month ?? -999) }
        case .return1Year:
            funds.sort { (fundPrices[$0.code]?.return1Year ?? -999) > (fundPrices[$1.code]?.return1Year ?? -999) }
        case .fundSize:
            funds.sort { (fundPrices[$0.code]?.fundSize ?? 0) > (fundPrices[$1.code]?.fundSize ?? 0) }
        case .alphabetical:
            funds.sort { $0.shortName < $1.shortName }
        }
        
        return funds
    }
    
    /// Get top performing funds
    func topPerformers(limit: Int = 5) -> [FundListItem] {
        return Array(sortedFunds(by: .return1Week).prefix(limit))
    }
    
    // MARK: - Refresh
    
    func refresh() async {
        await loadAllFunds()
    }
}
