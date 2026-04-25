import SwiftUI

struct ToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(title)
                .font(InstitutionalTheme.Typography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? InstitutionalTheme.Colors.primary : InstitutionalTheme.Colors.surface1)
                .foregroundColor(isOn ? .white : InstitutionalTheme.Colors.textPrimary)
                .cornerRadius(16)
        }
    }
}

struct ScoreItem: View {
    let title: String
    let score: Double?
    
    var body: some View {
        VStack {
            Text(title)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            if let s = score {
                Text("\(Int(s))")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .bold()
                    .foregroundColor(scoreColor(s))
            } else {
                Text("-")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score >= 50 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

struct AtlasMetricRow: View {
    let title: String
    let value: Double?
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                if let v = value {
                    Text("\(Int(v))/100")
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .bold()
                        .foregroundColor(scoreColor(v))
                } else {
                    Text("-")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstitutionalTheme.Colors.borderSubtle)
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
        .institutionalCard(scale: .standard, elevated: false)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score >= 50 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

struct DetailRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if text.contains(":") {
                let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
                Text(parts[0])
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.7))
                Spacer()
                Text(parts[1])
                    .font(InstitutionalTheme.Typography.caption)
                    .bold()
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(text)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding()
    }
}

struct WeightedSignalCard: View {
    let results: [StrategyResult]
    
    var body: some View {
        let (buy, sell, hold) = calculateWeights()
        
        VStack(spacing: 12) {
            Text("Ağırlıklı Sinyal Dağılımı")
                .font(InstitutionalTheme.Typography.bodyStrong)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if buy > 0 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.positive)
                            .frame(width: geometry.size.width * CGFloat(buy / 100))
                    }
                    if hold > 0 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.textSecondary)
                            .frame(width: geometry.size.width * CGFloat(hold / 100))
                    }
                    if sell > 0 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.negative)
                            .frame(width: geometry.size.width * CGFloat(sell / 100))
                    }
                }
            }
            .frame(height: 20)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(InstitutionalTheme.Colors.borderSubtle))
            
            HStack {
                Label("\(Int(buy))% AL", systemImage: "arrow.up.circle.fill").foregroundColor(InstitutionalTheme.Colors.positive).font(InstitutionalTheme.Typography.caption)
                Spacer()
                Label("\(Int(hold))% BEKLE", systemImage: "minus.circle.fill").foregroundColor(InstitutionalTheme.Colors.textSecondary).font(InstitutionalTheme.Typography.caption)
                Spacer()
                Label("\(Int(sell))% SAT", systemImage: "arrow.down.circle.fill").foregroundColor(InstitutionalTheme.Colors.negative).font(InstitutionalTheme.Typography.caption)
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
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

struct StrategyResultRow: View {
    let result: StrategyResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(result.strategyName)
                    .font(InstitutionalTheme.Typography.caption)
                    .bold()
                Text(result.summary)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(result.currentAction.rawValue)
                .font(InstitutionalTheme.Typography.caption)
                .bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color(for: result.currentAction))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .padding()
        .institutionalCard(scale: .micro, elevated: false)
    }
    
    private func color(for action: SignalAction) -> Color {
        switch action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.textSecondary
        case .wait: return InstitutionalTheme.Colors.textSecondary
        case .skip: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

struct AthenaFactorCard: View {
    let result: AthenaFactorResult
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Athena Faktör Analizi", systemImage: "building.columns.fill")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text(String(format: "%.0f", result.factorScore))
                    .font(InstitutionalTheme.Typography.headline)
                    .bold()
                    .foregroundColor(color(for: result.colorName))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color(for: result.colorName).opacity(0.2))
                    .cornerRadius(8)
                    .scaleEffect(animate ? 1.05 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            Text(result.styleLabel)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 5)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animate)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                factorRow(name: "Değer", score: result.valueFactorScore, delay: 0.1)
                factorRow(name: "Kalite", score: result.qualityFactorScore, delay: 0.2)
                factorRow(name: "Momentum", score: result.momentumFactorScore, delay: 0.3)
                factorRow(name: "Büyüklük", score: result.sizeFactorScore ?? 50, delay: 0.35)
                factorRow(name: "Risk", score: result.riskFactorScore, delay: 0.4, invertColor: true)
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg)
                .stroke(color(for: result.colorName).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            animate = true
        }
    }
    
    private func color(for name: String) -> Color {
        switch name {
        case "Green": return InstitutionalTheme.Colors.positive
        case "Blue": return InstitutionalTheme.Colors.primary
        case "Yellow": return InstitutionalTheme.Colors.warning
        case "Red": return InstitutionalTheme.Colors.negative
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    private func factorRow(name: String, score: Double, delay: Double, invertColor: Bool = false) -> some View {
        HStack {
            Text(name)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(InstitutionalTheme.Typography.caption)
                    .bold()
                    .foregroundColor(colorFor(score: score, invert: invertColor))
                
                Capsule()
                    .fill(colorFor(score: score, invert: invertColor))
                    .frame(width: 4, height: animate ? 12 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay), value: animate)
            }
        }
        .padding(8)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(6)
        .scaleEffect(animate ? 1 : 0.9)
        .opacity(animate ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(delay), value: animate)
    }
    
    private func colorFor(score: Double, invert: Bool) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score >= 40 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

struct InformationQualityCard: View {
    let weights: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bilgi Kalitesi Ağırlıkları", systemImage: "scalemass.fill")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            
            Text("Her modülün karar mekanizmasındaki güvenilirlik ve etki oranı.")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(weights.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text("%\(Int(value * 100))")
                            .font(InstitutionalTheme.Typography.dataSmall)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(value).opacity(0.2))
                            .foregroundColor(qualityColor(value))
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .institutionalCard(scale: .nano, elevated: false)
                }
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
    }
    
    private func qualityColor(_ value: Double) -> Color {
        if value >= 0.9 { return InstitutionalTheme.Colors.positive }
        if value >= 0.7 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}
