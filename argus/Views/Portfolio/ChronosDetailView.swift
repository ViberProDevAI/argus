import SwiftUI

struct ChronosDetailView: View {
    let symbol: String
    @StateObject private var viewModel: ChronosLabViewModel
    @EnvironmentObject var tradingViewModel: TradingViewModel
    
    init(symbol: String) {
        self.symbol = symbol
        // ViewModel dummy init, as EnvironmentObject is not available during init
         _viewModel = StateObject(wrappedValue: ChronosLabViewModel(initialSymbol: symbol))
    }
    
    var body: some View {
        ChronosLabView(viewModel: viewModel)
            .onAppear {
                // Now we can access environment object
                // We need to inject candles into the viewModel manually or init here
                // Better approach: Let viewModel access EnvironmentObject directly? No, VM logic.
                // Simpler: Just pass candles map to VM
                viewModel.setCandles(tradingViewModel.candles) 
            }
    }
}
