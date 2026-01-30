import SwiftUI

struct MimirView: View {
    @State private var issues: [MimirIssue] = []
    @State private var isScanning = false
    
    var body: some View {
        NavigationView {
            List {
                if issues.isEmpty {
                    if isScanning {
                        ProgressView("Taranıyor...")
                    } else {
                        Text("✅ Sistem Stabil (Sorun Yok)")
                            .foregroundColor(.green)
                    }
                } else {
                    ForEach(issues) { issue in
                        MimirIssueRow(issue: issue)
                    }
                }
                
                Section(header: Text("Provenance")) {
                    NavigationLink("Data Source Map", destination: Text("Aether -> FRED/Yahoo\nAtlas -> Finnhub/TwelveData\nPhoenix -> Yahoo"))
                }
            }
            .navigationTitle("Mimir Protocol 🛡️")
            .toolbar {
                Button(action: scan) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .onAppear(perform: scan)
        }
    }
    
    private func scan() {
        isScanning = true
        Task {
            let found = await MimirIssueDetector.shared.scan()
            await MainActor.run {
                self.issues = found
                self.isScanning = false
            }
        }
    }
}




