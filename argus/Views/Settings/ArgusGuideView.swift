import SwiftUI

struct ArgusGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "ARGUS REHBERİ",
                subtitle: "KONSEY · MOTOR · GÖREV",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [.custom(sfSymbol: "xmark", action: { presentationMode.wrappedValue.dismiss() })]
            )

            TabView {
                guidePage(
                    mode: .argus,
                    title: "ARGUS",
                    subtitle: "Karar Mekanizması",
                    description: "Argus, sistemin beynidir. Teknik, bilanço, makro, haber ve sektör katmanlarından gelen sinyalleri toplar; uzun vadeli (Core) ve kısa vadeli (Pulse) olmak üzere iki boyutta işler. Sonuç: Al, Sat ya da Bekle."
                )

                guidePage(
                    mode: .atlas,
                    title: "BİLANÇO",
                    subtitle: "Temel Analiz",
                    description: "Şirketin omurgasını inceleyen katmandır. Bilanço, gelir tablosu, borç yükü ve kârlılık oranlarına bakar; çarpanlarla gerçek değeri hesaplar. Bilanço onayı yoksa kalite zayıf demektir."
                )

                guidePage(
                    mode: .orion,
                    title: "TEKNİK",
                    subtitle: "Fiyat & Momentum",
                    description: "Grafiği okuyan katmandır. Trend, momentum, RSI, MACD gibi göstergelerle fiyatın yönünü ve zamanlamasını ölçer. Sinyali tetikleyen kısa vadeli tetikleyicidir."
                )

                guidePage(
                    mode: .aether,
                    title: "MAKRO",
                    subtitle: "Piyasa Ortamı",
                    description: "Genel ortamı okuyan katmandır. Faiz, enflasyon, VIX gibi makro veriler ve risk iştahı üzerinden pozisyonun büyüklüğünü ve risk dozunu belirler. Yön değil ölçek katmanıdır."
                )

                guidePage(
                    mode: .demeter,
                    title: "SEKTÖR",
                    subtitle: "Sektör Rotasyonu",
                    description: "Sermayenin akış yönünü izleyen katmandır. Teknoloji, enerji, bankacılık gibi sektörlerden hangisinin güçlendiğini ve hangisinin zayıfladığını analiz eder; rotasyondaki kazanan tarafa yönlendirir."
                )

                guidePage(
                    mode: .hermes,
                    title: "HABER",
                    subtitle: "Haber Akışı & Sentiment",
                    description: "Piyasanın kulağıdır. Binlerce haberi tarar, yapay zekayla özetler, tonunu (pozitif / negatif / nötr) sınıflandırır. Dedikoduyu kalıcı bilgi taşıyan haberden ayırır."
                )
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
    }
    
    private func guidePage(mode: ArgusMode, title: String, subtitle: String, description: String) -> some View {
        ZStack {
            // Background Animation
            GeometryReader { proxy in
                ZStack {
                    InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)
                    
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
