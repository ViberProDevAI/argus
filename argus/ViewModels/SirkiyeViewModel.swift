
import Foundation
import Combine

/// Sirkiye (BIST/Altın/Fon) Ekranı için Ana ViewModel
/// Global MarketDataProvider'dan BAĞIMSIZ çalışır.
class SirkiyeViewModel: ObservableObject {
    @Published var bistTickers: [String: BistTicker] = [:]
    @Published var institutionRates: [String: [InstitutionRate]] = [:] // Asset -> [Rate]
    @Published var funds: [String: FundDetail] = [:]
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Services
    private let bistService = BistDataService.shared
    private let dovizService = DovizComService.shared
    private let tefasService = TefasService.shared
    
    // BIST İzleme Listesi (Örnek)
    private let bistWatchlist = ["THYAO", "ASELS", "GARAN", "EREGL", "SISE"]
    
    // Altın/Döviz Varlıkları
    private let preciousMetals = ["gram-altin", "gram-gumus", "ons-altin"]
    
    init() {
        // Initial load
    }
    
    // MARK: - Data Fetching
    
    func refreshAll() async {
        await MainActor.run { isLoading = true }
        
        // Parallel Fetch
        async let bist = fetchBistWatchlist()
        async let metals = fetchMetalRates()
        
        // Wait for all
        _ = await (bist, metals)
        
        await MainActor.run { isLoading = false }
    }
    
    // MARK: - BIST Operations
    
    private func fetchBistWatchlist() async {
        await withTaskGroup(of: BistTicker?.self) { group in
            for symbol in bistWatchlist {
                group.addTask {
                    try? await self.bistService.fetchQuote(symbol: symbol)
                }
            }
            
            for await ticker in group {
                if let t = ticker {
                    await MainActor.run {
                        self.bistTickers[t.shortSymbol] = t
                    }
                }
            }
        }
    }
    
    // MARK: - Doviz.com Operations (Institution Rates)
    
    private func fetchMetalRates() async {
        await withTaskGroup(of: (String, [InstitutionRate])?.self) { group in
            for asset in preciousMetals {
                group.addTask {
                    do {
                        let rates = try await self.dovizService.fetchMetalInstitutionRates(asset: asset)
                        return (asset, rates)
                    } catch {
                        print("SirkiyeVM: Failed to fetch metals for \(asset): \(error)")
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let (asset, rates) = result {
                    await MainActor.run {
                        self.institutionRates[asset] = rates
                    }
                }
            }
        }
    }
    
    func getInstitutionRates(for asset: String) -> [InstitutionRate] {
        return institutionRates[asset] ?? []
    }
    
    // MARK: - TEFAS Operations
    
    func fetchFundDetail(code: String) async {
        // TEFAS Service henüz tam detail endpointine sahip değil, history üzerinden mockluyoruz.
        // İleride burası güncellenecek.
        // FundDetailView kendi datasını yüklüyor, burası global bir fon listesi için olabilir.
    }
}
