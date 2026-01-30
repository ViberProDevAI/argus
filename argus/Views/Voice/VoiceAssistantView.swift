import SwiftUI
import Combine

struct VoiceAssistantView: View {
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.large) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(DesignTokens.Fonts.title)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                    Spacer()
                    Text("Argus Asistan")
                        .font(DesignTokens.Fonts.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Visualizer
                VoiceVisualizerView(isListening: viewModel.isListening)
                    .frame(height: 200)
                
                Spacer()
                
                // Status / Response
                if viewModel.isLoading {
                    UnifiedLoadingView(message: "Düşünüyor...")
                        .frame(height: 100)
                } else if let error = viewModel.errorMessage {
                    UnifiedErrorView(message: error, retryAction: viewModel.startListening)
                        .frame(height: 200)
                } else {
                    Text(viewModel.responseText)
                        .font(DesignTokens.Fonts.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
                
                // Action Button
                Button(action: {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        viewModel.startListening()
                    }
                }) {
                    Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .padding(24)
                        .background(
                            Circle()
                                .fill(viewModel.isListening ? DesignTokens.Colors.error : DesignTokens.Colors.primary)
                                .shadow(color: (viewModel.isListening ? DesignTokens.Colors.error : DesignTokens.Colors.primary).opacity(0.5), radius: 20)
                        )
                }
                .padding(.bottom, 50)
            }
        }
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
                    .fill(DesignTokens.Colors.primary)
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
