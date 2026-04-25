import SwiftUI
import Combine

/// V5 Argus sesli asistanı — mic visualizer + yanıt. Legacy `DesignTokens`
/// referansları `InstitutionalTheme`'e, ad-hoc header `ArgusNavHeader`'a
/// geçti.
struct VoiceAssistantView: View {
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "ARGUS ASİSTAN",
                subtitle: "SES · KONUŞ · YORUMLA",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [
                    .custom(sfSymbol: "xmark", action: { presentationMode.wrappedValue.dismiss() })
                ]
            )

            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Visualizer
                    VoiceVisualizerView(isListening: viewModel.isListening)
                        .frame(height: 200)

                    Spacer()

                    // Status / Response
                    Group {
                        if viewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView().tint(InstitutionalTheme.Colors.holo)
                                Text("Düşünüyor...")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            .frame(height: 100)
                        } else if let error = viewModel.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(InstitutionalTheme.Colors.crimson)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Button {
                                    viewModel.startListening()
                                } label: {
                                    Text("TEKRAR DENE")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .tracking(1.2)
                                        .foregroundColor(InstitutionalTheme.Colors.background)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md)
                                                .fill(InstitutionalTheme.Colors.holo)
                                        )
                                }
                            }
                            .frame(height: 200)
                        } else {
                            Text(viewModel.responseText)
                                .font(.system(size: 16))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }

                    Spacer()

                    // Action Button — large mic
                    Button {
                        if viewModel.isListening {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    } label: {
                        Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding(24)
                            .background(
                                Circle()
                                    .fill(viewModel.isListening
                                          ? InstitutionalTheme.Colors.crimson
                                          : InstitutionalTheme.Colors.holo)
                                    .shadow(color: (viewModel.isListening
                                                    ? InstitutionalTheme.Colors.crimson
                                                    : InstitutionalTheme.Colors.holo).opacity(0.45),
                                            radius: 22)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// Mock ViewModel for UI construction logic
class VoiceAssistantViewModel: ObservableObject {
    @Published var isListening = false
    @Published var isLoading = false
    @Published var responseText = "Size nasıl yardımcı olabilirim?"
    @Published var errorMessage: String?

    func startListening() {
        isListening = true
        errorMessage = nil
        responseText = "Dinliyorum..."

        // Mock delay to simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isListening = false
            self.isLoading = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isLoading = false
                self.responseText = "Piyasalar bugün pozitif bir seyir izliyor. BIST 100 endeksi %1.5 yükselişte."
            }
        }
    }

    func stopListening() {
        isListening = false
    }
}

struct VoiceVisualizerView: View {
    var isListening: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(InstitutionalTheme.Colors.holo)
                    .frame(width: 4, height: isListening ? 50 : 10)
                    .animation(
                        isListening ?
                            Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1) : .default,
                        value: isListening
                    )
            }
        }
    }
}

#Preview {
    VoiceAssistantView()
}
