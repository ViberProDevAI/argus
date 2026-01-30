import SwiftUI

/// REJİM View
/// Makro/Piyasa Modu Gösterimi

struct RejimView: View {
    let symbol: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("REJİM: Makro/Piyasa Analizi")
                .font(.title)
                .foregroundColor(.white)
            
            Text("Sembol: \(symbol)")
                .foregroundColor(.secondary)
            
            // Placeholder - Backend'e bağlanacak
            ProgressView("REJİM modülü yükleniyor...")
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0F172A"))
    }
}
