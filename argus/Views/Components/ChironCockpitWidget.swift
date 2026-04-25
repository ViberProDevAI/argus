import SwiftUI

// MARK: - Chiron Cockpit Widget
/// Sistemin öğrenme durumunu tek satırda gösterir.
/// Geliştiriciye yönelik "weight update / rule change" logları UI'a sızmaz.
struct ChironCockpitWidget: View {
    @State private var recentEventCount: Int = 0
    @State private var showChironDetail = false

    var body: some View {
        // Öğrenme verisi yoksa widget'ı hiç gösterme
        if recentEventCount == 0 { return AnyView(EmptyView()) }

        return AnyView(
            Button(action: { showChironDetail = true }) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.green.opacity(0.85))
                        .frame(width: 7, height: 7)

                    Text("Sistem son \(recentEventCount) işlemi analiz etti")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .task {
                let events = await ChironDataLakeService.shared.loadLearningEvents()
                recentEventCount = events.count
            }
            .sheet(isPresented: $showChironDetail) {
                NavigationStack {
                    ChironInsightsView()
                }
            }
        )
    }
}

// MARK: - Backward compat shell (referenced elsewhere but no longer used in UI)
struct ChironEventChip: View {
    let event: ChironLearningEvent
    var body: some View { EmptyView() }
}
