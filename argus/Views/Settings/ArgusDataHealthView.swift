import SwiftUI


// Helper for Engine Health
struct EngineHealthCard: View {
    let status: EngineHealthSnapshot
    
    var color: Color {
        switch status.state {
        case .fresh: return .green
        case .stale: return .orange
        case .missing: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(status.engine.rawValue)
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            if let last = status.lastSuccessAt {
                Text(timeAgo(last))
                    .font(.caption2)
                    .foregroundColor(.white)
            } else {
                Text("Veri Yok")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if status.consecutiveFailures > 0 {
                Text("\(status.consecutiveFailures) Hata")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ArgusDataHealthView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    
    // Heimdall State
    @State private var systemHealth: HeimdallOrchestrator.SystemHealthStatus = .operational
    @State private var providerScores: [String: ProviderScore] = [:]
    @State private var quotaUsage: [String: ProviderQuotaStatus] = [:]
    
    // Debug Export State
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var issues: [MimirIssue] = []
    @State private var exportedText = ""
    @State private var isScanning = false
    
    func scanIssues() {
        isScanning = true
        Task {
            let found = await MimirIssueDetector.shared.scan()
            await MainActor.run {
                self.issues = found
                self.isScanning = false
            }
        }
    }

    func exportDebugBundle() {
        isExporting = true
        Task {
            let bundleText = await HeimdallDebugBundleExporter.shared.generateBundle()
            await MainActor.run {
                self.exportedText = bundleText
                self.isExporting = false
                self.showShareSheet = true
                
                // Auto Copy
                UIPasteboard.general.string = bundleText
            }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 0. Mimir Active Scanner (NEW)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "eye.square.fill")
                                .foregroundColor(.indigo)
                            Text("MIMIR PROTOCOL")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: scanIssues) {
                                Label(isScanning ? "Taranıyor..." : "Şimdi Tara", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.indigo.opacity(0.2))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(6)
                            }
                        }
                        
                        if issues.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Tüm sistemler normal.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                        } else {
                            ForEach(issues) { issue in
                                MimirIssueRow(issue: issue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    VStack(spacing: 8) {
                        HeimdallPulseView(status: systemHealth)
                            .frame(height: 150)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SİSTEM TELEMETRİSİ")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Theme.textSecondary)
                            HStack {
                                Text(systemHealth.rawValue.uppercased())
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(colorForHealth(systemHealth))
                                
                                Spacer()
                                
                                // Export Debug Bundle Button
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Button(action: exportDebugBundle) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "ladybug.fill")
                                            Text("Hata Ayıklama Paketi İndir")
                                                .font(.caption)
                                                .bold()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Theme.cardBackground)
                                        .foregroundColor(Theme.textSecondary)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .sheet(isPresented: $showShareSheet, content: {
                        ShareSheet(activityItems: [exportedText])
                    })

                    
                    // 2. Freeze Detective (Performance Metrics)
                    HStack(spacing: 16) {
                        // Boot Time
                        VStack(spacing: 4) {
                            Text("AÇILIŞ SÜRESİ")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.0f ms", viewModel.bootstrapDuration * 1000))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.bootstrapDuration > 1.0 ? .red : .green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        
                        // Watchlist Time
                        VStack(spacing: 4) {
                            Text("İZLEME LİSTESİ")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.0f ms", viewModel.lastBatchFetchDuration * 1000))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.lastBatchFetchDuration > 2.0 ? .orange : .green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // 2.5 Request Trace List
                    RequestTraceListView()
                        .padding(.horizontal)
                    
                    // 2.6 Failover Stories (NEW)
                    if !HeimdallTelepresence.shared.telemetry.failoverStories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OLAY GÜNLÜĞÜ (FAILOVER)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(HeimdallTelepresence.shared.telemetry.failoverStories, id: \.self) { story in
                                        Text(story)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 100)
                        }
                    }
                    
                    // 2.7 Engine Freshness (NEW)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MOTOR SAĞLIĞI & TAZELİK")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        let health = HeimdallTelepresence.shared.telemetry.engineHealth
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(EngineTag.allCases, id: \.self) { engine in
                                if let stat = health[engine] {
                                    EngineHealthCard(status: stat)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 2.8 Cache Inspector (NEW)
                    VStack(alignment: .leading, spacing: 16) {
                         Text("ÖNBELLEK YÖNETİMİ")
                             .font(.headline)
                             .foregroundColor(.white)
                             .padding(.horizontal)
                         
                         HStack {
                             Button(action: { DiskCacheService.shared.clearAll() }) {
                                 Label("Tüm Önbelleği Temizle", systemImage: "trash")
                                     .font(.caption)
                                     .foregroundColor(.red)
                                     .padding()
                                     .background(Color.red.opacity(0.1))
                                     .cornerRadius(8)
                             }
                             Spacer()
                             Button(action: { 
// Task { TradingViewModel().loadData() } // DISABLED: Prevents Zombie Instance creation / Race Condition
                             }) {
                                 Label("Zorla Yenile", systemImage: "arrow.clockwise.circle")
                                     .font(.caption)
                                     .foregroundColor(.blue)
                                     .padding()
                                     .background(Color.blue.opacity(0.1))
                                     .cornerRadius(8)
                             }
                         }
                         .padding(.horizontal)
                    }
                    
                    // 3. API Quota Usage (Ledger)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API Kotaları (Günlük)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            ForEach(quotaUsage.keys.sorted(), id: \.self) { provider in
                                if let usage = quotaUsage[provider] {
                                    QuotaRow(provider: provider, used: usage.success, limit: usage.limit)
                                }
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // 3. Provider Performance (Scores)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sağlayıcı Performansı")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(providerScores.keys.sorted(), id: \.self) { provider in
                                if let score = providerScores[provider] {
                                    ProviderScoreRow(name: provider, score: score)
                                    Divider().background(Theme.border)
                                }
                            }
                        }
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Veri Motoru Paneli")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshData()
        }
    }
    
    
    private func refreshData() {
        Task {
            // Fetch All Data from Actors
            let health = await HeimdallOrchestrator.shared.checkSystemHealth()
            let scores = await HeimdallOrchestrator.shared.getProviderScores()
            let quotas = await QuotaLedger.shared.getSnapshot()
            
            await MainActor.run {
                self.systemHealth = health
                self.providerScores = scores
                self.quotaUsage = quotas
            }
        }
    }
    
    // Helpers
    func colorForHealth(_ status: HeimdallOrchestrator.SystemHealthStatus) -> Color {
        switch status {
        case .operational: return .green
        case .degraded: return .yellow
        case .critical: return .red
        }
    }
    
    func iconForHealth(_ status: HeimdallOrchestrator.SystemHealthStatus) -> String {
        switch status {
        case .operational: return "checkmark.shield.fill"
        case .degraded: return "exclamationmark.shield.fill"
        case .critical: return "xmark.shield.fill"
        }
    }
}

// MARK: - Subcomponents

struct QuotaRow: View {
    let provider: String
    let used: Int
    let limit: Int
    
    var progress: Double {
        return min(1.0, Double(used) / Double(limit))
    }
    
    var color: Color {
        if progress > 0.9 { return .red }
        if progress > 0.7 { return .orange }
        return .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(provider)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(used) / \(limit)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.background)
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct ProviderScoreRow: View {
    let name: String
    let score: ProviderScore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                
                HStack(spacing: 12) {
                    Label("\(Int(score.latencyP50))ms", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if score.penaltyScore > 0 {
                        Label("Ceza: \(Int(score.penaltyScore))", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Circular Progress for Success Rate
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: CGFloat(score.successRate))
                    .stroke(score.successRate > 0.9 ? Color.green : (score.successRate > 0.5 ? Color.yellow : Color.red), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                
                Text("\(Int(score.successRate * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
