import SwiftUI
import Charts

// MARK: - Composite Score Badge (V5)
struct ScoreBadge: View {
    let score: CompositeScore
    
    var body: some View {
        HStack(spacing: 6) {
            // Visual Bar
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Theme.colorForScore(score.totalScore).opacity(0.6), Theme.colorForScore(score.totalScore)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 4, height: 24)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("SKOR")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text("\(Int(score.totalScore))")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Theme.colorForScore(score.totalScore))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.Radius.small)
    }
}

// MARK: - Detailed Signal Card (V5)
struct SignalCard: View {
    let signal: Signal
    @State private var showDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(signal.strategyName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(signal.reason)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                
                // Action Badge
                Text(signal.action.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorForAction(signal.action).opacity(0.2))
                    .foregroundColor(colorForAction(signal.action))
                    .cornerRadius(8)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Values
            HStack {
                ForEach(signal.indicatorValues.sorted(by: >), id: \.key) { key, value in
                    VStack(alignment: .leading) {
                        Text(key)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(value)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 10)
                }
            }
            
            // Education (Clickable)
            Button(action: { showDetail = true }) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(Theme.tint)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mantık: \(signal.logic)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                        
                        Text("İpucu: \(signal.successContext)")
                            .font(.caption)
                            .foregroundColor(Theme.tint.opacity(0.8))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showDetail) {
            SignalDetailView(signal: signal)
        }
    }
    
    private func colorForAction(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .hold: return Theme.neutral
        case .wait: return Theme.neutral
        case .skip: return Theme.neutral
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
                    // Header
                    HStack {
                        Text(signal.strategyName)
                            .font(.title2)
                            .bold()
                        Spacer()
                        Text(signal.action.rawValue)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(colorForAction(signal.action).opacity(0.2))
                            .foregroundColor(colorForAction(signal.action))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Simplified Explanation
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Basitleştirilmiş Anlatım", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundColor(Theme.tint)
                        
                        Text(signal.simplifiedExplanation)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Technical Details
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Teknik Detaylar", systemImage: "waveform.path.ecg")
                            .font(.headline)
                        
                        Text("Mevcut Değerler:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            ForEach(signal.indicatorValues.sorted(by: >), id: \.key) { key, value in
                                VStack {
                                    Text(key).font(.caption).foregroundColor(.secondary)
                                    Text(value).font(.title3).bold().fontDesign(.monospaced)
                                }
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("Sinyal Nedeni: \(signal.reason)")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                    
                    Spacer()
                }
                .padding()
            }
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
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .hold: return Theme.neutral
        case .wait: return Theme.neutral
        case .skip: return Theme.neutral
        }
    }
}

// MARK: - Mini Chart (For Lists)
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

// MARK: - Simple Candle Chart (For Detail)
struct SimpleCandleChart: View {
    let candles: [Candle]
    
    var body: some View {
        if candles.isEmpty {
            VStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Veri Yok")
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.Radius.medium)
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
                    .foregroundStyle(.gray)
                    
                    RectangleMark(
                        x: .value("Date", candle.date),
                        yStart: .value("Open", candle.open),
                        yEnd: .value("Close", candle.close),
                        width: 6
                    )
                    .foregroundStyle(candle.close >= candle.open ? Theme.positive : Theme.negative)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .frame(height: 240)
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.Radius.medium)
        }
    }
}

// MARK: - Shining Logo View (V9)
public struct ShiningLogoView: View {
    @State private var isShining = false
    
    public var body: some View {
        ZStack {
            // 1. Glow Background
            Circle()
                .fill(Theme.tint)
                .frame(width: 60, height: 60)
                .blur(radius: 20)
                .opacity(isShining ? 0.6 : 0.2)
                .scaleEffect(isShining ? 1.2 : 1.0)
            
            // 2. Static Logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(color: Theme.tint.opacity(0.5), radius: 10, x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isShining ? 0.8 : 0.2), lineWidth: 1)
                        .scaleEffect(isShining ? 1.05 : 1.0)
                        .opacity(isShining ? 0.0 : 1.0) // Ripple effect
                )
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                isShining = true
            }
        }
    }
}
