import SwiftUI

struct PhoenixView: View {
    @StateObject private var scanner = PhoenixScannerService.shared
    @State private var selectedMode: PhoenixScanMode = .balanced
    @State private var showLogs = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Control Center (Header)
                        VStack(spacing: 16) {
                            // Mode Selector
                            Picker("Mod", selection: $selectedMode) {
                                ForEach(PhoenixScanMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            
                            // Action Button
                            Button(action: startScan) {
                                HStack {
                                    if scanner.isScanning {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "flame.fill")
                                    }
                                    
                                    Text(scanner.isScanning ? "Taranıyor..." : "Phoenix Taramasını Başlat")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(scanner.isScanning ? Color.gray : Theme.positive)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(scanner.isScanning)
                            .padding(.horizontal)
                        }
                        
                        // 2. Live Status / Pipeline Stats
                        if let report = scanner.lastReport {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SON TARAMA RAPORU (\(timeString(from: report.timestamp)))")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal)
                                
                                PipelineStatsCard(report: report)
                                    .padding(.horizontal)
                                
                                // Logs Preview
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Son İşlemler:")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    ForEach(report.logs.suffix(3), id: \.self) { log in
                                        Text("• \(log)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    
                                    Button("Tüm Logları Gör") {
                                        showLogs = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(Theme.tint)
                                    .padding(.top, 4)
                                }
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        } else {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "binoculars.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(Theme.textSecondary)
                                Text("Henüz tarama yapılmadı.")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.top, 40)
                        }
                        
                        // 3. Candidates (Sent Symbols)
                        if let report = scanner.lastReport, !report.sentSymbols.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ONAYLANAN ADAYLAR (\(report.sentCount))")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(report.sentSymbols, id: \.self) { symbol in
                                        SentCandidateRow(symbol: symbol)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Phoenix Gözcü")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogs) {
                if let report = scanner.lastReport {
                    PhoenixRunLogView(report: report)
                }
            }
        }
    }
    
    func startScan() {
        Task {
            await scanner.runPipeline(mode: selectedMode)
        }
    }
    
    func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Subcomponents

struct PipelineStatsCard: View {
    let report: PhoenixRunReport
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            StatItem(label: "Bulunan", value: "\(report.candidatesFound)", icon: "magnifyingglass")
            Divider().background(Theme.border).frame(height: 40)
            StatItem(label: "Shortlist", value: "\(report.shortlistCount)", icon: "list.bullet")
            Divider().background(Theme.border).frame(height: 40)
            StatItem(label: "Onaylı", value: "\(report.verifiedCount)", icon: "checkmark.seal.fill", color: .green)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = Theme.textPrimary
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SentCandidateRow: View {
    let symbol: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(symbol)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                Text("Konsey tarafından inceleniyor")
                    .font(.caption2)
                    .foregroundColor(Theme.tint)
            }
            Spacer()
            Image(systemName: "paperplane.fill")
                .foregroundColor(Theme.tint)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Log View
struct PhoenixRunLogView: View {
    let report: PhoenixRunReport
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Özet")) {
                    HStack {
                        Text("Mod")
                        Spacer()
                        Text(report.mode.rawValue)
                    }
                    HStack {
                        Text("Bütçe Kullanımı")
                        Spacer()
                        Text("\(report.budgetUsed) / \(report.budgetLimit)")
                            .foregroundColor(report.stoppedByBudget ? .red : .primary)
                    }
                }
                
                Section(header: Text("Loglar")) {
                    ForEach(report.logs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                if !report.errors.isEmpty {
                    Section(header: Text("Hatalar")) {
                        ForEach(report.errors, id: \.self) { err in
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Tarama Detayları")
            .navigationBarItems(trailing: Button("Kapat") { presentationMode.wrappedValue.dismiss() })
        }
    }
}
