import SwiftUI

struct ChironEducationCard: View {
    let result: ChironResult
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.ignoresSafeArea()
            Color(hex: "080b14").ignoresSafeArea() // Deep Blue/Black
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SİSTEM DURUMU")
                        .font(.headline)
                        .tracking(2)
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Hero Pulse
                        ZStack {
                            Circle()
                                .fill(regimeColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 32))
                                .foregroundColor(regimeColor)
                            
                            // Orbital Rings
                            Circle()
                                .stroke(regimeColor.opacity(0.3), lineWidth: 1)
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(45))
                        }
                        .padding(.top, 20)
                        
                        // 2. Regime Title
                        VStack(spacing: 8) {
                            Text(result.explanationTitle)
                                .font(.title2)
                                .bold()
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                            
                            Text(result.explanationBody)
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal)
                        }
                        
                        // 3. Why This Engine? (Educational Part)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("NEDEN BU MOD?")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.gray)
                                .tracking(1)
                            
                            if engineType == "CORSE SWING" {
                                educationalRow(
                                    icon: "arrow.left.and.right",
                                    color: .orange,
                                    title: "Yatay Piyasa (Chop)",
                                    desc: "Fiyatlar bir yöne gitmiyor. Trend motoru (Orion) kapatıldı, destek/direnç motoru (Corse) açıldı."
                                )
                            }
                            else if engineType == "ORION ENGINE" {
                                educationalRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    color: .green,
                                    title: "Trend Piyasası",
                                    desc: "Güçlü bir akım var. Trend takip motoru (Orion) tam güç çalışıyor. 'Trend your friend' prensibi devrede."
                                )
                            }
                            else if engineType == "ATLAS SHIELD" {
                                educationalRow(
                                    icon: "shield.fill",
                                    color: .red,
                                    title: "Riskli Piyasa",
                                    desc: "Makro veriler (Aether) veya volatilite aşırı yüksek. Sermayeyi korumak için defansif moda geçildi."
                                )
                            }
                            else {
                                educationalRow(
                                    icon: "pause.circle",
                                    color: .blue,
                                    title: "Bekleme Modu",
                                    desc: "Piyasa ne sıcak ne soğuk. Standart ağırlıklar kullanılıyor. Fırsat bekleniyor."
                                )
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "0F172A"))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        .padding(.horizontal)
                        
                        
                        // 4. Weight Distribution (Visual Bar)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AĞIRLIK DAĞILIMI (LIVE)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.gray)
                                .tracking(1)
                                .padding(.horizontal)
                            
                            // Simple Bar Chart
                            weightRow(label: "Orion (Teknik)", pct: result.pulseWeights.orion, color: .cyan)
                            weightRow(label: "Atlas (Temel)", pct: result.pulseWeights.atlas, color: .purple)
                            weightRow(label: "Phoenix (Trend)", pct: result.pulseWeights.phoenix ?? 0, color: .orange)
                            weightRow(label: "Hermes (Haber)", pct: result.pulseWeights.hermes ?? 0, color: .pink)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
    
    private func educationalRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func weightRow(label: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(Int(pct * 100))%").font(.caption).bold().foregroundColor(.white)
            }
            
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(color).frame(width: max(0, g.size.width * pct))
                }
            }
            .frame(height: 6)
        }
    }
    
    private var regimeColor: Color {
        switch result.regime {
        case .trend: return .green
        case .riskOff: return .red
        case .chop: return .orange
        case .newsShock: return .purple
        case .neutral: return .blue
        }
    }
    
    private var engineType: String {
        switch result.regime {
        case .trend: return "ORION ENGINE"
        case .riskOff: return "ATLAS SHIELD"
        case .chop: return "CORSE SWING"
        case .newsShock: return "HERMES FEED"
        case .neutral: return "STANDBY"
        }
    }
}
