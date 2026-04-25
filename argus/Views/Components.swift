import SwiftUI
import Charts

struct ScoreBadge: View {
    let score: CompositeScore
    
    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [colorForScore(score.totalScore).opacity(0.6), colorForScore(score.totalScore)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 4, height: 24)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("SKOR")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                
                Text("\(Int(score.totalScore))")
                    .font(InstitutionalTheme.Typography.headline)
                    .foregroundColor(colorForScore(score.totalScore))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .institutionalCard(scale: .micro, elevated: false)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score >= 50 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

struct SignalCard: View {
    let signal: Signal
    @State private var showDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(signal.strategyName)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(signal.reason)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
                
                Text(signal.action.rawValue)
                    .font(InstitutionalTheme.Typography.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorForAction(signal.action).opacity(0.2))
                    .foregroundColor(colorForAction(signal.action))
                    .cornerRadius(8)
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            HStack {
                ForEach(signal.indicatorValues.sorted(by: >), id: \.key) { key, value in
                    VStack(alignment: .leading) {
                        Text(key)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text(value)
                            .font(InstitutionalTheme.Typography.dataSmall)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    .padding(.trailing, 10)
                }
            }
            
            Button(action: { showDetail = true }) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mantık: \(signal.logic)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineLimit(2)
                        
                        Text("İpucu: \(signal.successContext)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.primary.opacity(0.8))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.5))
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.surface1)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
        .sheet(isPresented: $showDetail) {
            SignalDetailView(signal: signal)
        }
    }
    
    private func colorForAction(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.textSecondary
        case .wait: return InstitutionalTheme.Colors.textSecondary
        case .skip: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

struct SignalDetailView: View {
    let signal: Signal
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(signal.strategyName)
                            .font(InstitutionalTheme.Typography.title)
                            .bold()
                        Spacer()
                        Text(signal.action.rawValue)
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(colorForAction(signal.action).opacity(0.2))
                            .foregroundColor(colorForAction(signal.action))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Basitleştirilmiş Anlatım", systemImage: "brain.head.profile")
                            .font(InstitutionalTheme.Typography.bodyStrong)
                            .foregroundColor(InstitutionalTheme.Colors.primary)
                        
                        Text(signal.simplifiedExplanation)
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .institutionalCard(scale: .standard, elevated: false)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Teknik Detaylar", systemImage: "waveform.path.ecg")
                            .font(InstitutionalTheme.Typography.bodyStrong)
                        
                        Text("Mevcut Değerler:")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        
                        HStack(spacing: 20) {
                            ForEach(signal.indicatorValues.sorted(by: >), id: \.key) { key, value in
                                VStack {
                                    Text(key).font(InstitutionalTheme.Typography.caption).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    Text(value).font(InstitutionalTheme.Typography.bodyStrong).fontDesign(.monospaced)
                                }
                                .padding(10)
                                .institutionalCard(scale: .micro, elevated: false)
                            }
                        }
                        
                        Text("Sinyal Nedeni: \(signal.reason)")
                            .font(InstitutionalTheme.Typography.caption)
                            .italic()
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(.top, 5)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("İndikatör Rehberi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func colorForAction(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.textSecondary
        case .wait: return InstitutionalTheme.Colors.textSecondary
        case .skip: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

struct MiniChart: View {
    let candles: [Candle]
    let color: Color
    
    var body: some View {
        Chart {
            ForEach(candles.suffix(20)) { candle in
                LineMark(
                    x: .value("Date", candle.date),
                    y: .value("Close", candle.close)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 60, height: 30)
    }
}

struct SimpleCandleChart: View {
    let candles: [Candle]
    
    var body: some View {
        if candles.isEmpty {
            VStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text("Veri Yok")
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .institutionalCard(scale: .hero, elevated: false)
        } else {
            let visible = Array(candles.suffix(40))
            
            Chart {
                ForEach(visible) { candle in
                    RectangleMark(
                        x: .value("Date", candle.date),
                        yStart: .value("Low", candle.low),
                        yEnd: .value("High", candle.high),
                        width: 1
                    )
                    .foregroundStyle(InstitutionalTheme.Colors.textSecondary)
                    
                    RectangleMark(
                        x: .value("Date", candle.date),
                        yStart: .value("Open", candle.open),
                        yEnd: .value("Close", candle.close),
                        width: 6
                    )
                    .foregroundStyle(candle.close >= candle.open ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .frame(height: 240)
            .padding()
            .institutionalCard(scale: .hero, elevated: false)
        }
    }
}
