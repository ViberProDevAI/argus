import SwiftUI

struct ArgusAnalystReportView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var displayedText: String = ""
    @State private var fullReportText: String = ""
    @State private var isLoading: Bool = true
    @State private var typewriterTimer: Timer?

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                    Text("ARGUS ANALYST")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .padding()
                .background(InstitutionalTheme.Colors.surface2)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(InstitutionalTheme.Colors.borderSubtle),
                    alignment: .bottom
                )

                // MARK: - Content
                if isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: InstitutionalTheme.Colors.primary))
                            .scaleEffect(1.2)
                        Text("\(symbol) analiz ediliyor...")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        Text(displayedText)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: - Footer
                HStack {
                    Spacer()
                    Text("Powered by ARGUS AI ENGINE")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .padding()
                }
            }
        }
        .onAppear {
            loadAIReport()
        }
        .onDisappear {
            typewriterTimer?.invalidate()
        }
    }

    // MARK: - AI Report Loading

    private func loadAIReport() {
        isLoading = true

        Task {
            let aiReport = await ArgusNarrativeEngine.generateAIReport(
                symbol: symbol,
                viewModel: viewModel,
                type: .comprehensive
            )

            await MainActor.run {
                fullReportText = aiReport
                isLoading = false
                startTypewriterEffect()
            }
        }
    }

    // MARK: - Typewriter Animation

    private func startTypewriterEffect() {
        displayedText = ""
        let chars = Array(fullReportText)
        var index = 0

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.003, repeats: true) { timer in
            if index < chars.count {
                displayedText.append(chars[index])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
