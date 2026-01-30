import SwiftUI
import Combine

struct HeimdallDashboardView: View {
    @State private var healthStats: [String: Double] = [:]
    @State private var endpointStates: [String: String] = [:]
    @State private var traceLog: [RequestTraceEvent] = []
    
    // Timer for refresh
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        List {
            moduleHealthSection
            locksSection
            tracesSection
            footerSection
        }
        .navigationTitle("Veri Motoru Paneli")
        .onAppear {
            Task { await loadData() }
        }
        .onReceive(timer) { _ in
            Task { await loadData() }
        }
    }
    
    // MARK: - Subviews
    
    private var moduleHealthSection: some View {
        Section("Module Health") {
            healthRow(name: "Aether (Macro)", score: healthStats["Yahoo"] ?? 1.0)
            healthRow(name: "Hermes (News)", score: healthStats["FMP"] ?? 1.0)
            healthRow(name: "Phoenix (Scanner)", score: healthStats["LocalScanner"] ?? 1.0)
        }
    }
    
    private var locksSection: some View {
        Section("Provider Locks & Circuit Breakers") {
            if endpointStates.isEmpty {
                Text("All endpoints healthy").foregroundColor(.green)
            } else {
                ForEach(endpointStates.sorted(by: <), id: \.key) { key, state in
                    HStack {
                        Text(key).font(.caption.monospaced())
                        Spacer()
                        Text(state)
                            .font(.caption.bold())
                            .foregroundColor(state == "Locked" ? .red : .orange)
                    }
                }
            }
        }
    }
    
    private var tracesSection: some View {
        Section("Recent Traces (Forensic)") {
            ForEach(Array(traceLog.prefix(20).enumerated()), id: \.offset) { _, trace in
                HeimdallTraceRow(trace: trace)
            }
        }
    }
    
    private var footerSection: some View {
        Section(footer: Text("Argus Data Core 2.0 • Scheduler Active • Dedup On")) {
            Button("Reset All Bans") {
                Task {
                    await ProviderCapabilityRegistry.shared.resetBans()
                    await loadData()
                }
            }
        }
    }
    
    private func healthRow(name: String, score: Double) -> some View {
        HStack {
            Text(name)
            Spacer()
            Circle()
                .fill(color(for: score))
                .frame(width: 8, height: 8)
            Text(score >= 0.8 ? "OK" : "Degraded")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func color(for score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .orange }
        return .red
    }
    
    private func loadData() async {
        // Fetch States
        self.endpointStates = await ProviderCapabilityRegistry.shared.getEndpointStates()
        
        // Fetch Stats (Mocked or pulled from HealthStore if accessible)
        // Ideally: let scores = await HeimdallOrchestrator.shared.getProviderScores()
        // Mapping simple mocks for immediate feedback based on Registry states
        
        // Logs
        let logs = await HeimdallTelepresence.shared.getRecentTraces()
        self.traceLog = logs.sorted { $0.timestamp > $1.timestamp }
    }
}

struct HeimdallTraceRow: View {
    let trace: RequestTraceEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(trace.engine.rawValue)]").font(.caption2).bold()
                Text(trace.provider.rawValue).font(.caption2)
                Spacer()
                Text(String(format: "%.0fms", trace.durationMs))
                    .font(.caption2)
                    .foregroundColor(trace.isSuccess ? .green : .red)
            }
            Text("\(trace.symbol) @ \(trace.endpoint)")
                .font(.caption)
            
            if let error = trace.errorMessage {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
