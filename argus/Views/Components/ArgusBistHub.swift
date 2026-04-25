import SwiftUI

struct ArgusBistHub: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("BIST INTELLIGENCE")
                        .font(.custom("Menlo-Bold", size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal)
                
                // 1. Sirkiye Makro Kokpit (Enflasyon, Faiz, USD)
                SirkiyeMacroCockpit(viewModel: viewModel)
                
                // 2. Yabancı Takas (Smart Money)
                if let flow = viewModel.foreignFlowData[symbol] {
                    ForeignFlowSentinel(flow: flow)
                } else {
                    ForeignFlowSentinel(flow: nil) // Empty State
                }
                
                // 3. Hibrit Puanlama (Argus Fusion)
                FusionScoreCard(symbol: symbol, viewModel: viewModel)
                
                // 4. KAP Bildirimleri
                if let kaps = viewModel.kapDisclosures[symbol], !kaps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KAP BİLDİRİMLERİ")
                            .font(.custom("Menlo-Bold", size: 12))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ForEach(kaps.prefix(3)) { news in // İlk 3 bildirim
                            KAPDisclosureRow(news: news)
                        }
                    }
                }
                
                // 5. Argus Akademi (Eğitici Bağlam)
                ArgusAcademyCard()
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemBackground)) // Theme uyumlu
    }
}

// MARK: - 1. Sirkiye Macro Cockpit
struct SirkiyeMacroCockpit: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MAKRO RÜZGAR (SIRKIYE)")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.gray)
                Spacer()
                // Durum Göstergesi
                if let regime = viewModel.macroRating {
                    let color: Color = regime.numericScore > 66 ? .green : (regime.numericScore > 33 ? .yellow : .red)
                    Text("Regime Score: \(Int(regime.numericScore))")
                        .font(.custom("Menlo-Bold", size: 10))
                        .padding(4)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Enflasyon Kartı
                    let inf = viewModel.tcmbData?.inflation ?? 0
                    RichMacroCard(
                        title: "ENFLASYON",
                        value: String(format: "%%%.1f", inf),
                        status: inf > 30 ? "Yüksek" : "Normal",
                        comment: inf > 40 ? "Enflasyon rallisini destekler." : "Stabil seyir.",
                        color: .red,
                        icon: "flame.fill"
                    )
                    
                    // Faiz Kartı
                    let rate = viewModel.tcmbData?.policyRate ?? 0
                    RichMacroCard(
                        title: "POLİTİKA FAİZİ",
                        value: String(format: "%%%.0f", rate),
                        status: rate > 40 ? "Sıkı" : "Gevşek",
                        comment: rate > 45 ? "Mevduat borsaya rakip." : "Para borsaya akar.",
                        color: .blue,
                        icon: "building.columns.fill"
                    )
                    
                    // Reel Getiri
                    let real = rate - inf
                    RichMacroCard(
                        title: "REEL FAİZ",
                        value: String(format: "%%%.1f", real),
                        status: real < 0 ? "Negatif" : "Pozitif",
                        comment: real < 0 ? "Yatırımcıyı borsaya zorlar (Pozitif)." : "Borsa için baskı unsuru.",
                        color: real > 0 ? .orange : .green, // Negatif reel faiz borsa için yeşildir
                        icon: "percent"
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RichMacroCard: View {
    let title: String
    let value: String
    let status: String
    let comment: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.custom("Menlo-Bold", size: 10))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.custom("Menlo-Bold", size: 20))
                .foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(color)
                
                Text(comment)
                    .font(.custom("Menlo", size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(width: 160, height: 140)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 3. Fusion Score Card (Argus Brain)
struct FusionScoreCard: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    var orionScore: Double { viewModel.orionScores[symbol]?.score ?? 0 }
    var atlasScore: Double { viewModel.getFundamentalScore(for: symbol)?.totalScore ?? 0 }
    var hermesScore: Double { viewModel.newsInsightsBySymbol[symbol]?.first?.impactScore ?? 50 }
    
    // EPS ve ROE verilerini al
    var eps: Double? { viewModel.getFundamentalScore(for: symbol)?.financials?.earningsPerShare }
    var roe: Double? { viewModel.getFundamentalScore(for: symbol)?.financials?.returnOnEquity }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ARGUS ÇEKİRDEK KARARI")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                
                VStack(spacing: 0) {
                    // Üst Kısım: Bileşenler
                    HStack(spacing: 0) {
                        ScoreComponent(
                            title: "TEKNİK",
                            score: orionScore,
                            detail: "Trend & Momentum",
                            color: .cyan
                        )
                        Divider().background(Color.white.opacity(0.1))
                        ScoreComponent(
                            title: "TEMEL",
                            score: atlasScore,
                            detail: "Bilanço & Değer",
                            color: .purple
                        )
                        Divider().background(Color.white.opacity(0.1))
                        ScoreComponent(
                            title: "HABER",
                            score: hermesScore,
                            detail: "Sentiment",
                            color: .orange
                        )
                    }
                    .padding()
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Alt Kısım: Detaylı Açıklama (Context)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEDEN BU PUAN?")
                            .font(.custom("Menlo-Bold", size: 10))
                            .foregroundColor(.gray)
                        
                        // Dinamik Yorum Üretimi
                        let comment = generateComment()
                        Text(comment)
                            .font(.custom("Menlo", size: 12))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Kritik Veriler
                        if let e = eps, let r = roe {
                            HStack {
                                HubBadge(text: "EPS: \(String(format: "%.2f", e))", color: e > 0 ? .green : .red)
                                HubBadge(text: "ROE: %\(String(format: "%.1f", r))", color: r > 30 ? .green : .yellow)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                }
            }
            .padding(.horizontal)
        }
    }
    
    func generateComment() -> String {
        var parts: [String] = []
        
        if orionScore > 70 { parts.append("Teknik göstergeler güçlü AL sinyali veriyor.") }
        else if orionScore < 30 { parts.append("Teknik göstergeler aşırı satımda.") }
        
        if atlasScore > 70 { parts.append("Şirket temelleri sağlam, hisse iskontolu.") }
        else if atlasScore < 40 { parts.append("Temel veriler zayıf veya hisse pahalı.") }
        
        if viewModel.tcmbData?.inflation ?? 0 > 40 {
            parts.append("Enflasyonist ortam hisseyi destekliyor.")
        }
        
        return parts.joined(separator: " ")
    }
}

struct ScoreComponent: View {
    let title: String
    let score: Double
    let detail: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.custom("Menlo-Bold", size: 10))
                .foregroundColor(color)
            
            Text(String(format: "%.0f", score))
                .font(.custom("Menlo-Bold", size: 24))
                .foregroundColor(.white)
            
            Text(detail)
                .font(.custom("Menlo", size: 8))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HubBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.custom("Menlo-Bold", size: 10))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - 2. Foreign Flow Sentinel
struct ForeignFlowSentinel: View {
    let flow: ForeignInvestorFlowService.ForeignFlowData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YABANCI TAKAS (SENTINEL)")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.gray)
                Spacer()
                if let f = flow {
                    Text(f.timestamp.formatted(date: .numeric, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                
                if let f = flow {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(f.trend.rawValue)
                                .font(.custom("Menlo-Bold", size: 18))
                                .foregroundColor(colorForTrend(f.trend))
                            
                            Text("Analiz: \(getComment(for: f.trend))")
                                .font(.custom("Menlo", size: 10))
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                            
                            Text("Yabancı Payı: %\(String(format: "%.2f", f.foreignRatio))")
                                .font(.custom("Menlo", size: 10))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        // Bar Visualization
                        VStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Rectangle()
                                    .fill(barColor(for: i, trend: f.trend))
                                    .frame(width: 30, height: 6)
                                    .cornerRadius(2)
                            }
                        }
                    }
                    .padding()
                } else {
                    Text("Veri bekleniyor...")
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .frame(height: 80)
            .padding(.horizontal)
        }
    }
    
    func colorForTrend(_ trend: ForeignInvestorFlowService.FlowTrend) -> Color {
        switch trend {
        case .strongBuy, .buy: return .green
        case .neutral: return .yellow
        case .sell, .strongSell: return .red
        }
    }
    
    func barColor(for index: Int, trend: ForeignInvestorFlowService.FlowTrend) -> Color {
        let activeColor = colorForTrend(trend)
        let intensity: Int
        
        switch trend {
        case .strongBuy: intensity = 5
        case .buy: intensity = 3
        case .neutral: intensity = 1
        case .sell: intensity = 3
        case .strongSell: intensity = 5
        }
        
        // Alttan yukarı (5-i)
        return (5 - index) <= intensity ? activeColor : activeColor.opacity(0.2)
    }
    
    func getComment(for trend: ForeignInvestorFlowService.FlowTrend) -> String {
        switch trend {
        case .strongBuy: return "Smart Money (Akıllı Para) agresif şekilde mal topluyor. Borsa genelinde veya bu hissede ralli sinyali."
        case .buy: return "Yabancı ilgisi pozitif. Portföye ekleme yapıyorlar. Fiyatı destekler."
        case .neutral: return "Yabancı kararsız. Net bir yön tayini yok, piyasa yerli yatırımcıya bakıyor."
        case .sell: return "Yabancı çıkışı var. Satış baskısı oluşabilir, yükselişler satış fırsatı olabilir."
        case .strongSell: return "Dikkat! Yabancı agresif satıyor. Düşüş derinleşebilir, temkinli olunmalı."
        }
    }
}

// MARK: - 5. Argus Academy Card
struct ArgusAcademyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.cyan)
                Text("VERİLERİ NASIL OKUMALIYIM?")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.cyan)
            }
            
            Group {
                Text("• Enflasyon & Faiz:").bold().foregroundColor(.white) +
                Text(" Eğer enflasyon faizden yüksekse (Negatif Reel Faiz), paranız erir. Bu durumda borsa, enflasyondan korunma aracı olarak cazip hale gelir.")
                
                Text("• Yabancı Takas:").bold().foregroundColor(.white) +
                Text(" BIST'te trendi genelde yabancılar belirler. Yabancı alıyorsa tahta sahiplidir ve yükseliş kalıcı olabilir. Satıyorsa yükselişler tepki alımıdır.")
                
                Text("• Hibrit Skor:").bold().foregroundColor(.white) +
                Text(" Argus sizin için Teknik (Grafik), Temel (Bilanço) ve Haberleri birleştirir. Tek bir veriye değil, resmin bütününe odaklanır.")
            }
            .font(.custom("Menlo", size: 10))
            .foregroundColor(.gray)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

