import SwiftUI

struct DisclaimerView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer: Bool = false
    @State private var canAccept: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Icon & Title
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                    
                    Text("YASAL UYARI")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)
                
                // Content Scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        disclaimerText(title: "1. YATIRIM TAVSİYESİ DEĞİLDİR", content: "Bu uygulama (Argus Terminal), yalnızca finansal verileri analiz etmek ve matematiksel modeller sunmak amacıyla geliştirilmiştir. Uygulama içerisindeki hiçbir veri, grafik, analiz veya 'AI Konseyi' yorumu, Sermaye Piyasası Kurulu (SPK) kapsamında bir 'Yatırım Tavsiyesi' değildir. Alım-satım kararları tamamen kullanıcının kendi sorumluluğundadır.")
                        
                        disclaimerText(title: "2. RİSK BİLDİRİMİ", content: "Finansal piyasalar (Hisse Senedi, Kripto Para, Forex vb.) yüksek risk içerir. Yatırımlarınızın tamamını veya bir kısmını kaybedebilirsiniz. Geçmiş performanslar, gelecek sonuçların garantisi değildir. Argus Terminal'in sunduğu tahminler olasılık hesaplarına dayanır ve kesinlik içermez.")
                        
                        disclaimerText(title: "3. YAZILIM GARANTİSİ VE SORUMLULUK REDDİ", content: "Bu yazılım 'OLDUĞU GİBİ' (AS-IS) sunulmuştur. Geliştirici ekip, yazılımın hatasız olduğunu, kesintisiz çalışacağını veya verilerin %100 doğru olduğunu garanti etmez. Uygulamanın kullanımı, veri hataları veya teknik aksaklıklar nedeniyle oluşabilecek doğrudan veya dolaylı hiçbir maddi/manevi zarardan Argus Ekibi sorumlu tutulamaz.")
                        
                        disclaimerText(title: "4. KULLANIM KOŞULLARI", content: "Uygulamayı kullanarak, piyasa risklerini anladığınızı ve tüm sorumluluğun şahsınıza ait olduğunu, geliştiriciyi herhangi bir zarardan dolayı sorumlu tutmayacağınızı kabul etmiş olursunuz.")
                        
                        Text("Son Güncelleme: 26.12.2025")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.top, 20)
                    }
                    .padding(24)
                }
                .background(Color(white: 0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Action Button
                Button {
                    withAnimation {
                        hasAcceptedDisclaimer = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Okudum, Anladım ve Kabul Ediyorum")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        canAccept 
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                    .shadow(color: canAccept ? .blue.opacity(0.5) : .clear, radius: 10)
                }
                .disabled(!canAccept)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .onAppear {
                    // Force user to look at the screen for 2 seconds before button activates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            canAccept = true
                        }
                    }
                }
            }
        }
    }
    
    private func disclaimerText(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.orange)
                .bold()
            
            Text(content)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DisclaimerView()
}
