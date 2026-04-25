import SwiftUI

/// V5 Mimir paneli — sistem bütünlüğü tarayıcısı, provenance haritası.
/// NavigationView + toolbar yerine `ArgusNavHeader` kullanır.
struct MimirView: View {
    @State private var issues: [MimirIssue] = []
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "MIMIR PROTOCOL",
                subtitle: "SİSTEM BÜTÜNLÜĞÜ · PROVENANCE",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [
                    .custom(sfSymbol: "arrow.clockwise", action: scan)
                ]
            )

            List {
                Section {
                    if issues.isEmpty {
                        if isScanning {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.8)
                                Text("Taranıyor...")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                        } else {
                            HStack(spacing: 8) {
                                ArgusDot(color: InstitutionalTheme.Colors.aurora, size: 6)
                                Text("Sistem Stabil · Sorun Yok")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(InstitutionalTheme.Colors.aurora)
                            }
                        }
                    } else {
                        ForEach(issues) { issue in
                            MimirIssueRow(issue: issue)
                        }
                    }
                } header: {
                    ArgusSectionCaption("TARAMA · BÜTÜNLÜK")
                }

                Section {
                    NavigationLink {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aether → FRED / Yahoo")
                            Text("Atlas → Finnhub / TwelveData")
                            Text("Phoenix → Yahoo")
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .padding()
                    } label: {
                        Text("Data Source Map")
                            .font(.system(size: 12, weight: .semibold))
                    }
                } header: {
                    ArgusSectionCaption("PROVENANCE")
                }
            }
            .scrollContentBackground(.hidden)
            .background(InstitutionalTheme.Colors.background)
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear(perform: scan)
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
