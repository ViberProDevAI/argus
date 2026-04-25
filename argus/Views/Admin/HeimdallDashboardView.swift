import SwiftUI
import Combine

/// V5 Heimdall admin paneli — module health, provider lock/CB, trace log.
/// Legacy `.navigationTitle` yerine `ArgusNavHeader` + section caption.
struct HeimdallDashboardView: View {
    @State private var healthStats: [String: Double] = [:]
    @State private var endpointStates: [String: String] = [:]
    @State private var traceLog: [RequestTraceEvent] = []

    // Timer for refresh
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "HEIMDALL · DATA CORE",
                subtitle: "VERİ MOTORU · SAĞLIK · FORENSİK",
                leadingDeco: .bars3([.holo, .text, .text])
            )

            List {
                moduleHealthSection
                locksSection
                tracesSection
                footerSection
            }
            .scrollContentBackground(.hidden)
            .background(InstitutionalTheme.Colors.background)
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            Task { await loadData() }
        }
        .onReceive(timer) { _ in
            Task { await loadData() }
        }
    }

    // MARK: - Subviews

    private var moduleHealthSection: some View {
        Section {
            healthRow(name: "Aether (Macro)", score: healthStats["Yahoo"] ?? 1.0)
            healthRow(name: "Hermes (News)", score: healthStats["FMP"] ?? 1.0)
            healthRow(name: "Phoenix (Scanner)", score: healthStats["LocalScanner"] ?? 1.0)
        } header: {
            ArgusSectionCaption("MODULE HEALTH")
        }
    }

    private var locksSection: some View {
        Section {
            if endpointStates.isEmpty {
                HStack(spacing: 8) {
                    ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 6)
                    Text("All endpoints healthy")
                        .foregroundColor(InstitutionalTheme.Colors.aurora)
                }
            } else {
                ForEach(endpointStates.sorted(by: <), id: \.key) { key, state in
                    HStack {
                        Text(key)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text(state)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(state == "Locked"
                                             ? InstitutionalTheme.Colors.crimson
                                             : InstitutionalTheme.Colors.titan)
                    }
                }
            }
        } header: {
            ArgusSectionCaption("PROVIDER LOCKS · CIRCUIT BREAKERS")
        }
    }

    private var tracesSection: some View {
        Section {
            ForEach(Array(traceLog.prefix(20).enumerated()), id: \.offset) { _, trace in
                HeimdallTraceRow(trace: trace)
            }
        } header: {
            ArgusSectionCaption("RECENT TRACES · FORENSIC")
        }
    }

    private var footerSection: some View {
        Section {
            Button {
                Task {
                    await ProviderCapabilityRegistry.shared.resetBans()
                    await loadData()
                }
            } label: {
                Text("RESET ALL BANS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
            }
        } footer: {
            Text("Argus Data Core 2.0 · Scheduler Active · Dedup On")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
    }

    private func healthRow(name: String, score: Double) -> some View {
        HStack {
            Text(name)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            ArgusDot(color: color(for: score), size: 6)
            Text(score >= 0.8 ? "OK" : "Degraded")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    private func color(for score: Double) -> Color {
        if score >= 0.8 { return InstitutionalTheme.Colors.aurora }
        if score >= 0.5 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    private func loadData() async {
        self.endpointStates = await ProviderCapabilityRegistry.shared.getEndpointStates()
        let logs = await HeimdallTelepresence.shared.getRecentTraces()
        self.traceLog = logs.sorted { $0.timestamp > $1.timestamp }
    }
}

struct HeimdallTraceRow: View {
    let trace: RequestTraceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("[\(trace.engine.rawValue)]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                Text(trace.provider.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                Text(String(format: "%.0fms", trace.durationMs))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(trace.isSuccess
                                     ? InstitutionalTheme.Colors.aurora
                                     : InstitutionalTheme.Colors.crimson)
            }
            Text("\(trace.symbol) @ \(trace.endpoint)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            if let error = trace.errorMessage {
                Text("Error: \(error)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
            }
        }
        .padding(.vertical, 2)
    }
}
