import SwiftUI

struct ArgusAnalystReportView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var displayedText: String = ""
    @State private var fullReportText: String = ""
    
    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
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
                
                // Report Content
                ScrollView {
                    Text(displayedText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Footer
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
            fullReportText = generateReport()
            startTypewriterEffect()
        }
    }
    
    func startTypewriterEffect() {
        displayedText = ""
        let chars = Array(fullReportText)
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.003, repeats: true) { timer in
            if index < chars.count {
                displayedText.append(chars[index])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    func generateReport() -> String {
        return ArgusNarrativeEngine.generateReport(symbol: symbol, viewModel: viewModel)
    }
}
