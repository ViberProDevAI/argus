import SwiftUI

// MARK: - Toggle Button
struct ToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Theme.tint : Theme.secondaryBackground)
                .foregroundColor(isOn ? .white : Theme.textPrimary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Score Item
struct ScoreItem: View {
    let title: String
    let score: Double?
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let s = score {
                Text("\(Int(s))")
                    .font(.headline)
                    .bold()
                    .foregroundColor(scoreColor(s))
            } else {
                Text("-")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return Theme.positive }
        if score >= 50 { return Theme.warning }
        return Theme.negative
    }
}

// MARK: - Score Details Sheet
// MARK: - Atlas Metric Row (New Modern Component)
struct AtlasMetricRow: View {
    let title: String
    let value: Double?
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                if let v = value {
                    Text("\(Int(v))/100")
                        .font(.headline)
                        .bold()
                        .foregroundColor(scoreColor(v))
                } else {
                    Text("-")
                        .foregroundColor(.gray)
                }
            }
            
            // Modern Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    if let v = value {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor(v))
                            .frame(width: geometry.size.width * CGFloat(v / 100), height: 6)
                    }
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return Theme.positive }
        if score >= 50 { return Theme.warning }
        return Theme.negative
    }
}

// MARK: - Score Details Sheet (Modernized Atlas UI)
struct ScoreDetailsSheet: View {
    let score: FundamentalScoreResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Professional)
                HStack {
                    Text("Atlas Temel Analiz")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Theme.secondaryBackground)
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Theme.background)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.secondaryBackground), alignment: .bottom)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 1. Overview Card
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 6)
                                    .opacity(0.3)
                                    .foregroundColor(scoreColor(score.totalScore))
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(score.totalScore / 100, 1.0)))
                                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                                    .foregroundColor(scoreColor(score.totalScore))
                                    .rotationEffect(Angle(degrees: 270.0))
                                
                                Text("\(Int(score.totalScore))")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(scoreColor(score.totalScore))
                            }
                            .frame(width: 80, height: 80)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(score.valuationGrade ?? "Nötr")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                Text(score.summary.replacingOccurrences(of: ".", with: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Theme.secondaryBackground.opacity(0.5))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // 2. Metrics Grid
                        VStack(spacing: 12) {
                            AtlasMetricRow(title: "Karlılık", value: score.profitabilityScore, icon: "chart.line.uptrend.xyaxis")
                            AtlasMetricRow(title: "Büyüme", value: score.growthScore, icon: "arrow.up.right.circle")
                            AtlasMetricRow(title: "Finansal Sağlık", value: score.leverageScore, icon: "shield.checkerboard")
                            AtlasMetricRow(title: "Nakit Akışı", value: score.cashQualityScore, icon: "banknote")
                        }
                        .padding(.horizontal)
                        
                        // 3. Pro Insights (AI-like)
                        if !score.proInsights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Atlas Görüşü", systemImage: "eye")
                                    .font(.headline)
                                    .foregroundColor(Theme.tint)
                                
                                ForEach(score.proInsights, id: \.self) { insight in
                                    HStack(alignment: .top) {
                                        Circle().fill(Theme.tint).frame(width: 6, height: 6).padding(.top, 8)
                                        Text(insight) // Markdown support handled by SwiftUI automatically mostly? No, strip MD manually if needed or use Text
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineSpacing(4)
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // 4. Raw Details (Collapsed/Small)
                        DisclosureGroup("Tüm Veriler ve Hesaplama") {
                            Text(score.calculationDetails)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(Theme.secondaryBackground.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .accentColor(.gray)
                        
                    }
                    .padding(.bottom, 40)
                    .padding(.top)
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return Theme.positive }
        if score >= 50 { return Theme.warning }
        return Theme.negative
    }
}

struct DetailRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Attempt to separate Label and Value if contains ":"
            if text.contains(":") {
                let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
                Text(parts[0])
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(parts[1])
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                    .foregroundColor(.white) // Plain white
                    .multilineTextAlignment(.trailing)
            } else {
                Text(text)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Weighted Signal Card
struct WeightedSignalCard: View {
    let results: [StrategyResult]
    
    var body: some View {
        let (buy, sell, hold) = calculateWeights()
        
        VStack(spacing: 12) {
            Text("Ağırlıklı Sinyal Dağılımı")
                .font(.headline)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if buy > 0 {
                        Rectangle()
                            .fill(Theme.positive)
                            .frame(width: geometry.size.width * CGFloat(buy / 100))
                    }
                    if hold > 0 {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: geometry.size.width * CGFloat(hold / 100))
                    }
                    if sell > 0 {
                        Rectangle()
                            .fill(Theme.negative)
                            .frame(width: geometry.size.width * CGFloat(sell / 100))
                    }
                }
            }
            .frame(height: 20)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
            
            HStack {
                Label("\(Int(buy))% AL", systemImage: "arrow.up.circle.fill").foregroundColor(Theme.positive).font(.caption)
                Spacer()
                Label("\(Int(hold))% BEKLE", systemImage: "minus.circle.fill").foregroundColor(.gray).font(.caption)
                Spacer()
                Label("\(Int(sell))% SAT", systemImage: "arrow.down.circle.fill").foregroundColor(Theme.negative).font(.caption)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func calculateWeights() -> (Double, Double, Double) {
        var totalScore = 0.0
        var buyWeight = 0.0
        var sellWeight = 0.0
        
        for result in results {
            totalScore += result.score
            if result.currentAction == .buy {
                buyWeight += result.score
            } else if result.currentAction == .sell {
                sellWeight += result.score
            }
        }
        
        if totalScore == 0 { return (0, 0, 0) }
        
        let buy = (buyWeight / totalScore) * 100
        let sell = (sellWeight / totalScore) * 100
        let hold = 100.0 - buy - sell
        
        return (buy, sell, hold)
    }
    

}

// MARK: - Strategy Result Row
struct StrategyResultRow: View {
    let result: StrategyResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(result.strategyName)
                    .font(.subheadline)
                    .bold()
                Text(result.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(result.currentAction.rawValue)
                .font(.caption)
                .bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color(for: result.currentAction))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }
    
    private func color(for action: SignalAction) -> Color {
        switch action {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .hold: return .gray
        case .wait: return .gray
        case .skip: return .gray
        }
    }
}

// MARK: - Animated Athena Factor Card
struct AthenaFactorCard: View {
    let result: AthenaFactorResult
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with Pulse
            HStack {
                Label("Athena Faktör Analizi", systemImage: "building.columns.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f", result.factorScore))
                    .font(.title3)
                    .bold()
                    .foregroundColor(color(for: result.colorName))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color(for: result.colorName).opacity(0.2))
                    .cornerRadius(8)
                    .scaleEffect(animate ? 1.05 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Style Label
            Text(result.styleLabel)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 5)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animate)
            
            // Grid with Staggered Bars - NOW 5 FACTORS (Added Size)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                factorRow(name: "Değer", score: result.valueFactorScore, delay: 0.1)
                factorRow(name: "Kalite", score: result.qualityFactorScore, delay: 0.2)
                factorRow(name: "Momentum", score: result.momentumFactorScore, delay: 0.3)
                factorRow(name: "Büyüklük", score: result.sizeFactorScore ?? 50, delay: 0.35) // NEW: Size Factor
                factorRow(name: "Risk", score: result.riskFactorScore, delay: 0.4, invertColor: true)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color(for: result.colorName).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            animate = true
        }
    }
    
    private func color(for name: String) -> Color {
        switch name {
        case "Green": return Theme.positive
        case "Blue": return .blue
        case "Yellow": return Theme.warning
        case "Red": return Theme.negative
        default: return .gray
        }
    }
    
    private func factorRow(name: String, score: Double, delay: Double, invertColor: Bool = false) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            
            // Animated Bar + Value
            HStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(colorFor(score: score, invert: invertColor))
                
                Capsule()
                    .fill(colorFor(score: score, invert: invertColor))
                    .frame(width: 4, height: animate ? 12 : 0) // Grow Data Bar
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay), value: animate)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
        .scaleEffect(animate ? 1 : 0.9)
        .opacity(animate ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(delay), value: animate)
    }
    
    private func colorFor(score: Double, invert: Bool) -> Color {
        if score >= 70 { return Theme.positive }
        if score >= 40 { return Theme.warning }
        return Theme.negative
    }
}

// MARK: - Information Quality Card
struct InformationQualityCard: View {
    let weights: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bilgi Kalitesi Ağırlıkları", systemImage: "scalemass.fill")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Her modülün karar mekanizmasındaki güvenilirlik ve etki oranı.")
                .font(.caption)
                .foregroundColor(.gray)
            
            Divider().background(Color.white.opacity(0.1))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(weights.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("%\(Int(value * 100))")
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(value).opacity(0.2))
                            .foregroundColor(qualityColor(value))
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Theme.background) // Slightly different bg or card style
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
    }
    
    private func qualityColor(_ value: Double) -> Color {
        if value >= 0.9 { return Theme.positive }
        if value >= 0.7 { return Theme.warning }
        return Theme.negative
    }
}
