import SwiftUI

struct ArgusFlightRecorderView: View {
    @StateObject private var logger = AutoPilotLogger.shared
    @AppStorage("isAutoPilotLoggingEnabled") private var isLoggingEnabled = false
    @State private var showingExporter = false
    @State private var exportURL: URL?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            // Section 1: Controls
            Section {
                Toggle("Otopilot Günlüğünü Kaydet", isOn: $isLoggingEnabled)
                    .tint(.purple)
                
                if isLoggingEnabled {
                    Text("Otopilot'un aldığı her karar (Al/Sat/Tut) arka planda kaydediliyor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Kara Kutu (Black Box)")
            }
            
            // Section 2: Quick Stats
            Section {
                LabeledContent("Toplam Kayıt", value: "\(logger.decisions.count)")
                if let last = logger.decisions.last {
                    LabeledContent("Son Kayıt", value: last.timestamp.formatted(date: .numeric, time: .shortened))
                    LabeledContent("Son Karar", value: last.action.uppercased())
                }
            } header: {
                Text("Durum")
            }
            
            // Section 3: Recent Logs
            Section("Son Kararlar") {
                if logger.decisions.isEmpty {
                    Text("Henüz kayıt yok.")
                        .foregroundStyle(.secondary)
                } else {
                    List(logger.decisions.suffix(10).reversed()) { decision in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(decision.symbol)
                                    .font(.headline)
                                Spacer()
                                Text(decision.action.uppercased())
                                    .font(.caption)
                                    .padding(4)
                                    .background(actionColor(decision.action).opacity(0.2))
                                    .foregroundStyle(actionColor(decision.action))
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                if let prov = decision.provider {
                                    Text(prov)
                                        .font(.caption2)
                                        .padding(2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(2)
                                }
                                Text(decision.timestamp.formatted(date: .omitted, time: .standard))
                                Spacer()
                                if let score = decision.argusFinalScore {
                                    Text("Argus: \(Int(score))")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Section 4: Actions
            Section {
                Button {
                    exportCSV()
                } label: {
                    Label("CSV Olarak Dışa Aktar", systemImage: "tablecells")
                }
                
                Button {
                    exportJSON()
                } label: {
                    Label("JSON Olarak Dışa Aktar", systemImage: "doc.text")
                }
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Günlüğü Sıfırla", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Uçuş Kayıtçısı")
        .sheet(isPresented: $showingExporter) {
            if let url = exportURL {
                FlightRecorderShareSheet(activityItems: [url])
            }
        }
        .alert("Emin misiniz?", isPresented: $showingDeleteAlert) {
            Button("Sil", role: .destructive) {
                logger.clearAll()
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Tüm kayıtlı Otopilot kararları silinecek.")
        }
    }
    
    // Helpers
    private func exportCSV() {
        do {
            exportURL = try logger.exportAsCSVTempFile()
            showingExporter = true
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    private func exportJSON() {
        do {
            exportURL = try logger.exportAsJSONTempFile()
            showingExporter = true
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    private func actionColor(_ action: String) -> Color {
        switch action.lowercased() {
        case "buy": return .green
        case "sell": return .red
        case "hold": return .orange
        default: return .gray
        }
    }
}

// ShareSheet Helper
private struct FlightRecorderShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
