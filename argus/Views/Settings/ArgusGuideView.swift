import SwiftUI

struct ArgusGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        TabView {
            guidePage(
                mode: .argus,
                title: "ARGUS",
                subtitle: "Karar Mekanizması",
                description: "Argus, sistemin beynidir. Atlas, Orion, Aether, Demeter ve Hermes'ten gelen sinyalleri toplar, Core (Uzun Vade) ve Pulse (Kısa Vade) olarak iki ayrı boyutta işler. Son kararı o verir: Al, Sat, Bekle."
            )
            
            guidePage(
                mode: .atlas,
                title: "ATLAS",
                subtitle: "Temel Analiz",
                description: "Atlas, şirketin omurgasını inceler. Bilanço, gelir tablosu, borç yükü ve kârlılık oranlarına bakar. Bir şirketin 'gerçek' değerini hesaplar. Atlas onaylamıyorsa, temel çürüktür."
            )
            
            guidePage(
                mode: .orion,
                title: "ORION",
                subtitle: "Teknik Avcı",
                description: "Orion, grafikleri tarar. Trendleri, momentumu, RSI ve MACD gibi indikatörleri izler. Fiyatın 'nereye gittiğini' ve 'ne zaman' hareket edeceğini söyler. Sinyali tetikleyen tetikçidir."
            )
            
            guidePage(
                mode: .aether,
                title: "AETHER",
                subtitle: "Piyasa Atmosferi",
                description: "Aether, havayı koklar. Makroekonomik verileri (Faiz, Enflasyon, VIX) ve piyasa risk iştahını ölçer. Fırtına varsa sığınağa, güneş varsa denize yönlendirir. Risk yönetimi ondan sorulur."
            )
            
            guidePage(
                mode: .demeter,
                title: "DEMETER",
                subtitle: "Sektör Rotasyonu",
                description: "Demeter, sermayenin akış yönünü izler. Hangi sektörün (Teknoloji, Enerji, Bankacılık) güçlendiğini ve hangisinin zayıfladığını analiz eder. Paranın gittiği yerde olmanızı sağlar, ölü sektörlerden korur."
            )
            
            guidePage(
                mode: .hermes,
                title: "HERMES",
                subtitle: "Haberci",
                description: "Hermes, piyasanın kulağıdır. Binlerce haberi okur, yapay zeka ile özetler ve 'Yatırımcı Dili'ne çevirir. Duygusal analizi yapar, dedikoduyu gerçek haberden ayırır."
            )
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .background(Theme.background.edgesIgnoringSafeArea(.all))
        .overlay(
            // Close Button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
            , alignment: .topTrailing
        )
    }
    
    private func guidePage(mode: ArgusMode, title: String, subtitle: String, description: String) -> some View {
        ZStack {
            // Background Animation
            GeometryReader { proxy in
                ZStack {
                    Theme.background.edgesIgnoringSafeArea(.all)
                    
                    // The Eye - Centered and Large
                    ArgusEyeView(
                        mode: mode,
                        size: proxy.size.width * 0.8,
                        isElliptical: mode == .argus // Make Argus elliptical here too
                    )
                        .opacity(0.3) // Faded to be background
                        .blur(radius: 5) // Slight blur for depth
                        .offset(y: -20) // Slightly adjust position
                }
            }
            
            // Foreground Content
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 350) // Push text down to let the eye breathe a bit or overlap nicely
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(mode.color)
                            .tracking(4)
                            .shadow(color: mode.color.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        Text(subtitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Material.ultraThin) // Glassmorphism
                                .shadow(radius: 10)
                        )
                        .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
}
