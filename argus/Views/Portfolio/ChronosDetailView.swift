import SwiftUI

// Chronos Lab kaldırıldı — V5 geçişinde (2026-04-22) artık V5
// ChironInsightsView'a yönlendiriyor.
struct ChronosDetailView: View {
    let symbol: String
    init(symbol: String) { self.symbol = symbol }

    var body: some View {
        ChironInsightsView(symbol: symbol)
    }
}
