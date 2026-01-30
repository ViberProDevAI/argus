import SwiftUI

struct ArgusAnalystReportView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var displayedText: String = ""
    @State private var fullReportText: String = ""
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(SanctumTheme.hologramBlue)
                    Text("ARGUS ANALYST")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(SanctumTheme.hologramBlue)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(white: 0.1))
                
                // Report Content
                ScrollView {
                    Text(displayedText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Footer
                HStack {
                    Spacer()
                    Text("Powered by ARGUS AI ENGINE")
                        .font(.caption2)
                        .foregroundColor(.gray)
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
