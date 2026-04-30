import SwiftUI

// MARK: - Chiron Cockpit Widget
/// Sistemin öğrenme durumunu tek satırda gösterir.
/// Geliştiriciye yönelik "weight update / rule change" logları UI'a sızmaz.
struct ChironCockpitWidget: View {
    @State private var recentEventCount: Int = 0
    @State private var showChironDetail = false

    var body: some View {
        // Önceden AnyView wrapper'ı vardı; @ViewBuilder + if ile native diff,
        // body type'ı opaque kalır, SwiftUI yapısal kimliği takip edebilir.
        // Group dış kabuğu task modifier'ını count==0 olsa bile garanti eder
        // (eski kodda count==0 → EmptyView → task hiç çalışmazdı, sayım
        //  yapılamazdı; potansiyel bug. Group + task ile her zaman bir kez
        //  yüklenir, content ise sadece sayım > 0 ise render olur).
        Group {
            if recentEventCount > 0 {
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
                .sheet(isPresented: $showChironDetail) {
                    NavigationStack {
                        ChironInsightsView()
                    }
                }
            }
        }
        .task {
            let events = await ChironDataLakeService.shared.loadLearningEvents()
            recentEventCount = events.count
        }
    }
}

// MARK: - Backward compat shell (referenced elsewhere but no longer used in UI)
struct ChironEventChip: View {
    let event: ChironLearningEvent
    var body: some View { EmptyView() }
}
