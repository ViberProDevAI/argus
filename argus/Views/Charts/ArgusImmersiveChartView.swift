import SwiftUI

struct ArgusImmersiveChartView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    // UI State
    @State private var showTools = true
    @State private var selectedTimeframe: String = "1G"
    @State private var isLoading = false
    
    // Drawing State
    @State private var activeTool: DrawingType? = nil
    @State private var drawings: [ChartDrawing] = []
    
    private let timeframes = ["1S", "5D", "15D", "1G", "4S", "1H", "1A"]
    
    // Computed ChartData - Reaktif olarak viewModel'den okuyor
    private var chartData: ChartData {
        // KEY FIX: Timeframe bazlı anahtar kullan (ör: "AAPL_1G", "AAPL_1S")
        let cacheKey = "\(symbol)_\(selectedTimeframe)"
        if let candles = viewModel.candles[cacheKey] {
            let points = candles.map { $0.toChartPoint() }
            return ChartData(symbol: symbol, points: points, timeframe: selectedTimeframe)
        }
        return ChartData.empty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(red: 0.06, green: 0.06, blue: 0.1)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        // Symbol & Price Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symbol)
                                .font(.headline)
                                .bold()
                                .foregroundColor(.white)
                            
                            if let lastPrice = chartData.points.last?.close {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.2f", lastPrice))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    
                                    if let firstPrice = chartData.points.first?.close, firstPrice > 0 {
                                        let change = ((lastPrice - firstPrice) / firstPrice) * 100
                                        Text(String(format: "%+.2f%%", change))
                                            .font(.caption)
                                            .foregroundColor(change >= 0 ? .green : .red)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Timeframe Picker
                        HStack(spacing: 6) {
                            ForEach(timeframes, id: \.self) { tf in
                                Button(action: { 
                                    selectedTimeframe = tf
                                    isLoading = true
                                    Task {
                                        await viewModel.loadCandles(for: symbol, timeframe: tf)
                                        await MainActor.run {
                                            isLoading = false
                                        }
                                    }
                                }) {
                                    if isLoading && selectedTimeframe == tf {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Text(tf)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(selectedTimeframe == tf ? Color.blue.opacity(0.3) : Color.clear)
                                            .foregroundColor(selectedTimeframe == tf ? .blue : .gray)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Close Button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.5))
                    
                    // The Chart Engine (Connected)
                    if isLoading {
                        Spacer()
                        ProgressView("Veri yükleniyor...")
                            .foregroundColor(.white)
                        Spacer()
                    } else if chartData.points.isEmpty {
                        Spacer()
                        Text("Bu periyot için veri bulunamadı.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {

                        // NEW: Argus Pro Chart (Canvas Engine)
                        if let candles = viewModel.candles["\(symbol)_\(selectedTimeframe)"] {
                            ArgusProChart(candles: candles)
                                .overlay(
                                    // Drawing Mode Indicator
                                    Group {
                                        if let tool = activeTool {
                                            VStack {
                                                HStack {
                                                    Image(systemName: tool.icon)
                                                    Text("\(tool == .trendLine ? "Trend Çizgisi" : "Fibonacci") Çiziliyor")
                                                }
                                                .padding(8)
                                                .background(Color.blue.opacity(0.8))
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                                .font(.caption)
                                                .padding(.top, 10)
                                                Spacer()
                                            }
                                        }
                                    }
                                )
                                
                            // X-Axis Time Labels
                            xAxisTimeLabels
                                .frame(height: 30)
                                .background(Color.black.opacity(0.3))
                        } else {
                            Text("Mum verisi işlenemedi.")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Floating Tools (Right Side - Top Aligned)
                if showTools && !chartData.points.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 12) {
                                // Pointer / Pan (Default)
                                ToolButton(
                                    icon: "cursorarrow.rays",
                                    label: "Pan",
                                    isSelected: activeTool == nil,
                                    action: { activeTool = nil }
                                )
                                
                                // Trend Line
                                ToolButton(
                                    icon: "line.diagonal",
                                    label: "Trend",
                                    isSelected: activeTool == .trendLine,
                                    action: { activeTool = .trendLine }
                                )
                                
                                // Fibonacci
                                ToolButton(
                                    icon: "f.cursive",
                                    label: "Fib",
                                    isSelected: activeTool == .fibonacci,
                                    action: { activeTool = .fibonacci }
                                )
                                
                                Divider().background(Color.gray).frame(width: 30)
                                
                                // Clear All
                                ToolButton(
                                    icon: "trash",
                                    label: "Sil",
                                    isSelected: false,
                                    color: .red,
                                    action: { drawings.removeAll() }
                                )
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.trailing, 12)
                        }
                        Spacer()
                    }
                    .padding(.top, 80) // Below top bar
                }
            }
            .overlay(
                // Rotate Device Overlay (UX Fix 1)
                Group {
                    if geometry.size.height > geometry.size.width {
                        ZStack {
                            Color.black.edgesIgnoringSafeArea(.all)
                            VStack(spacing: 20) {
                                Image(systemName: "iphone.landscape")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(90))
                                    .symbolEffect(.bounce, options: .repeating)
                                
                                Text("Lütfen Ekranı Çevirin")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                Text("Argus Gelişmiş Grafik Motoru en iyi\nyatay modda çalışır.")
                                    .multilineTextAlignment(.center)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Button("Kapat") { dismiss() }
                                    .padding(.top, 40)
                            }
                        }
                    }
                }
            )
        }
        .statusBar(hidden: true)
        .onAppear {
            drawings = DrawingPersistence.shared.loadDrawings(for: symbol)
        }
        .onDisappear {
            DrawingPersistence.shared.saveDrawings(drawings, for: symbol)
        }
    }
    
    // MARK: - X-Axis Helpers
    
    private var xAxisTimeLabels: some View {
        GeometryReader { geo in
            let step = max(1, chartData.points.count / 6)
            HStack {
                ForEach(Array(stride(from: 0, to: chartData.points.count, by: step)), id: \.self) { index in
                    if index < chartData.points.count {
                        Text(formatDate(chartData.points[index].timestamp))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    if index < chartData.points.count - step { Spacer() }
                }
            }
            .padding(.horizontal, 70)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        switch selectedTimeframe {
        case "1S", "5D", "15D": formatter.dateFormat = "HH:mm"
        case "1G", "4S": formatter.dateFormat = "dd MMM"
        default: formatter.dateFormat = "MMM yy"
        }
        return formatter.string(from: date)
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    var isSelected: Bool = false
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundColor(isSelected ? .blue : color.opacity(0.8))
            .frame(width: 40)
            .padding(4)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
    }
}

#Preview {
    ArgusImmersiveChartView(
        viewModel: TradingViewModel(),
        symbol: "AAPL"
    )
}


