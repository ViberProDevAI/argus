import SwiftUI

// MARK: -  Grafik Eğitici Kartı (SAR TRY, TSI, RSI)
// Teknik analiz verilerini "Veri → Hesaplama → Sonuç" formatında gösterir

struct GrafikEducationalCard: View {
    let symbol: String
    @State private var orionResult: OrionBistResult?
    @State private var rsiValue: Double?
    @State private var macdValue: Double?
    @State private var isLoading = true
    @State private var isExpanded = true
    
    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    Text("Teknik Analiz Göstergeleri")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if let r = orionResult {
                        Text(r.signal.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(signalColor(r.signal).opacity(0.2))
                            .foregroundColor(signalColor(r.signal))
                            .cornerRadius(8)
                    }
                }
                
                if !isLoading {
                    // 1️⃣ SAR TRY (Parabolic SAR)
                    IndicatorRow(
                        icon: "arrow.triangle.swap",
                        title: "SAR TRY (Parabolic SAR)",
                        value: orionResult?.sarStatus ?? "N/A",
                        color: orionResult?.sarStatus.contains("AL") == true ? .green : .red,
                        explanation: sarExplanation,
                        formula: "SAR(n+1) = SAR(n) + AF × (EP - SAR(n))"
                    )
                    
                    // 2️⃣ TSI (True Strength Index)
                    IndicatorRow(
                        icon: "gauge.with.dots.needle.50percent",
                        title: "TSI (Momentum)",
                        value: String(format: "%.1f", orionResult?.tsiValue ?? 0),
                        color: tsiColor(orionResult?.tsiValue ?? 0),
                        explanation: tsiExplanation,
                        formula: "TSI = 100 × EMA(EMA(ΔFiyat)) / EMA(EMA(|ΔFiyat|))"
                    )
                    
                    // 3️⃣ RSI
                    if let rsi = rsiValue {
                        IndicatorRow(
                            icon: "speedometer",
                            title: "RSI (14)",
                            value: String(format: "%.0f", rsi),
                            color: rsiColor(rsi),
                            explanation: rsiExplanation(rsi),
                            formula: "RSI = 100 - (100 / (1 + RS))"
                        )
                    }
                    
                    // 4️⃣ Sonuç Puanı
                    if let r = orionResult {
                        Divider().background(Color.white.opacity(0.2))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "target")
                                        .font(.caption2)
                                        .foregroundColor(.cyan)
                                    Text("TOPLAM SKOR")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Text("\(Int(r.score))/100")
                                    .font(.title2.bold())
                                    .foregroundColor(signalColor(r.signal))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("SİNYAL")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(r.signal.rawValue)
                                    .font(.headline)
                                    .foregroundColor(signalColor(r.signal))
                            }
                        }
                        .padding()
                        .background(signalColor(r.signal).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { loadData() }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        Task {
            var bistCandles: [BistCandle] = []
            
            // 1. Önce BorsaPy (İş Yatırım) dene
            do {
                let data = try await BorsaPyProvider.shared.getBistHistory(symbol: symbol, days: 60)
                if !data.isEmpty {
                    print("✅ GrafikEducationalCard: BorsaPy'dan \(symbol) için \(data.count) mum alındı")
                    bistCandles = data.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                }
            } catch {
                print("⚠️ GrafikEducationalCard: BorsaPy başarısız (\(symbol)), Yahoo'ya fallback...")
            }
            
            // 2. BorsaPy başarısız olduysa HeimdallOrchestrator (Yahoo) fallback
            if bistCandles.isEmpty {
                do {
                    let yahooCandles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 60)
                    if !yahooCandles.isEmpty {
                        print("✅ GrafikEducationalCard: Yahoo'dan \(symbol) için \(yahooCandles.count) mum alındı")
                        bistCandles = yahooCandles.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                    }
                } catch {
                    print("❌ GrafikEducationalCard: Yahoo da başarısız (\(symbol)): \(error.localizedDescription)")
                }
            }
            
            // 3. Hala veri yoksa çık
            guard !bistCandles.isEmpty else {
                print("❌ GrafikEducationalCard: \(symbol) için hiçbir kaynaktan veri alınamadı")
                await MainActor.run { self.isLoading = false }
                return
            }
            
            // 4. Orion BIST analizi
            let result = OrionBistEngine.shared.analyze(candles: bistCandles)
            print("✅ GrafikEducationalCard: Orion analizi tamamlandı - Skor: \(result.score)")
            
            // 5. RSI hesapla
            let candles = bistCandles.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            let closes = candles.map { $0.close }
            let rsiValues = IndicatorService.calculateRSI(values: closes, period: 14)
            let currentRSI = rsiValues.last.flatMap { $0 }
            
            await MainActor.run {
                self.orionResult = result
                self.rsiValue = currentRSI
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Explanations
    private var sarExplanation: String {
        guard let sar = orionResult?.sarStatus else { return "" }
        if sar.contains("AL") {
            return "Fiyat SAR'ın üzerinde → Yükseliş trendi devam ediyor. SAR noktaları fiyatın altında."
        } else {
            return "Fiyat SAR'ın altında → Düşüş trendi hakim. SAR noktaları fiyatın üzerinde."
        }
    }
    
    private var tsiExplanation: String {
        guard let tsi = orionResult?.tsiValue else { return "" }
        if tsi > 20 { return "Güçlü pozitif momentum. Alıcılar kontrolde." }
        if tsi > 0 { return "Pozitif momentum ama zayıf. Trend doğrulanmadı." }
        if tsi > -20 { return "Negatif momentum ama güçlü değil. Satış baskısı sınırlı." }
        return "Güçlü negatif momentum. Satıcılar kontrolde."
    }
    
    private func rsiExplanation(_ rsi: Double) -> String {
        if rsi > 70 { return "⚠️ Aşırı alım bölgesi! Düzeltme riski yüksek." }
        if rsi > 50 { return "Alıcı baskısı hakim. Trend yukarı yönlü." }
        if rsi > 30 { return "Satıcı baskısı hakim. Trend aşağı yönlü." }
        return "⚠️ Aşırı satım bölgesi! Tepki yükselişi gelebilir."
    }
    
    // MARK: - Colors
    private func signalColor(_ signal: OrionBistSignal) -> Color {
        switch signal {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        }
    }
    
    private func tsiColor(_ tsi: Double) -> Color {
        if tsi > 20 { return .green }
        if tsi > 0 { return .yellow }
        if tsi > -20 { return .orange }
        return .red
    }
    
    private func rsiColor(_ rsi: Double) -> Color {
        if rsi > 70 { return .red }
        if rsi > 50 { return .green }
        if rsi > 30 { return .orange }
        return .green
    }
}

// MARK: - Indicator Row (Reusable)
struct IndicatorRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let explanation: String
    let formula: String
    
    @State private var showFormula = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(color)
            }
            
            // Explanation
            Text(explanation)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            // Formula (Tıkla göster)
            Button(action: { withAnimation { showFormula.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "function")
                        .font(.caption2)
                    Text(showFormula ? "Formülü gizle" : "Formülü göster")
                        .font(.caption2)
                }
                .foregroundColor(.cyan.opacity(0.7))
            }
            
            if showFormula {
                Text(formula)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(8)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Orion Rölatif Güç Kartı
// BIST hisselerinin endekse göre performansını gösterir

struct OrionRelativeStrengthCard: View {
    let symbol: String
    @State private var result: RelativeStrengthResult?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.purple)
                        Text("Endekse Göre Performans")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else if let r = result {
                            Text(r.statusText)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(r.status).opacity(0.2))
                                .foregroundColor(statusColor(r.status))
                                .cornerRadius(8)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let r = result {
                    // Ana Metrikler (Her zaman görünür)
                    HStack(spacing: 16) {
                        MetricMiniCard(title: "RS", value: String(format: "%.2f", r.relativeStrength), color: rsColor(r.relativeStrength))
                        MetricMiniCard(title: "Beta", value: String(format: "%.2f", r.beta), color: betaColor(r.beta))
                        MetricMiniCard(title: "Mom.", value: String(format: "%.1f%%", r.momentum), color: momentumColor(r.momentum))
                    }
                    
                    // Genişletilmiş Detay
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(Color.white.opacity(0.2))
                            
                            // Sektör Bilgisi
                            HStack {
                                Text("Sektör:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(r.sector)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            // Detaylı Metrikler
                            ForEach(r.metrics) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(metric.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(metric.score))/\(Int(metric.maxScore))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Text(metric.explanation)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    // Formül
                                    HStack(spacing: 4) {
                                        Image(systemName: "function")
                                            .font(.system(size: 10))
                                            .foregroundColor(.cyan.opacity(0.7))
                                        Text(metric.formula)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.cyan.opacity(0.7))
                                    }
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear { loadData() }
        }
    }
    
    private func loadData() {
        Task {
            // XU100 mumlarını çek
            var xu100Candles: [Candle]? = nil
            if let xu100 = try? await BorsaPyProvider.shared.getBistHistory(symbol: "XU100", days: 60) {
                xu100Candles = xu100.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            }
            
            // Hisse mumlarını çek
            if let stockData = try? await BorsaPyProvider.shared.getBistHistory(symbol: symbol, days: 60) {
                let stockCandles = stockData.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                
                if let data = try? await OrionRelativeStrengthEngine.shared.analyze(symbol: symbol, candles: stockCandles, benchmarkCandles: xu100Candles) {
                    await MainActor.run {
                        self.result = data
                        self.isLoading = false
                    }
                    return
                }
            }
            
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func statusColor(_ status: RSStatus) -> Color {
        switch status {
        case .outperforming: return .green
        case .stable: return .blue
        case .neutral: return .yellow
        case .underperforming: return .red
        }
    }
    
    private func rsColor(_ rs: Double) -> Color {
        if rs > 1.1 { return .green }
        if rs > 0.95 { return .yellow }
        return .red
    }
    
    private func betaColor(_ beta: Double) -> Color {
        if beta < 0.9 { return .blue }
        if beta < 1.2 { return .yellow }
        return .orange
    }
    
    private func momentumColor(_ m: Double) -> Color {
        if m > 5 { return .green }
        if m > 0 { return .yellow }
        return .red
    }
}

// MARK: - Hermes Analist Kartı

struct HermesAnalystCard: View {
    let symbol: String
    let currentPrice: Double
    var newsDecision: HermesDecision? = nil // Opsiyonel haber verisi
    
    @State private var result: HermesAnalystResult?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.orange)
                        Text("Analist Konsensüsü")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else if let r = result, r.consensus.totalAnalysts > 0 {
                            Text(r.verdict)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(verdictColor(r.verdict).opacity(0.2))
                                .foregroundColor(verdictColor(r.verdict))
                                .cornerRadius(8)
                        } else if newsDecision != nil {
                            // Veri yok ama haber var -> "Kulis Modu" Badge
                            Text("KULİS MODU")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let r = result, r.consensus.totalAnalysts > 0 {
                    // --- STANDART MOD (Analist Verisi Var) ---
                    
                    // Konsensüs Bar
                    HStack(spacing: 2) {
                        // AL
                        if r.consensus.buyCount > 0 {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: CGFloat(r.consensus.buyCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                        // TUT
                        if r.consensus.holdCount > 0 {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: CGFloat(r.consensus.holdCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                        // SAT
                        if r.consensus.sellCount > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: CGFloat(r.consensus.sellCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    // Analist Sayıları
                    HStack {
                        Label("\(r.consensus.buyCount) AL", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        Label("\(r.consensus.holdCount) TUT", systemImage: "minus")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Spacer()
                        Label("\(r.consensus.sellCount) SAT", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Hedef Fiyat
                    if let target = r.consensus.averageTargetPrice {
                        HStack {
                            Text("Hedef Fiyat:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("₺\(String(format: "%.2f", target))")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            
                            if let upside = r.upsidePotential {
                                Text("(\(upside >= 0 ? "+" : "")\(String(format: "%.1f", upside))%)")
                                    .font(.caption)
                                    .foregroundColor(upside >= 0 ? .green : .red)
                            }
                        }
                    }
                    
                    // Genişletilmiş Detay
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(Color.white.opacity(0.2))
                            
                            ForEach(r.metrics) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(metric.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(metric.value)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(Int(metric.score))/\(Int(metric.maxScore))")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                    Text(metric.explanation)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .transition(.opacity)
                    }
                } else if !isLoading {
                    // --- LITE MOD (Analist Yok, Haber Var) ---
                    if let news = newsDecision {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Analist verisi yetersiz, ancak piyasa dedikoduları var:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Sentiment Göstergesi
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(sentimentColor(news.sentiment).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: sentimentIcon(news.sentiment))
                                        .font(.title3)
                                        .foregroundColor(sentimentColor(news.sentiment))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(news.sentiment.displayTitle)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(news.isHighImpact ? "Yüksek Piyasa Etkisi" : "Normal Piyasa Algısı")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Başlıklar
                            if !news.keyHeadlines.isEmpty {
                                Divider().background(Color.white.opacity(0.1))
                                Text("Öne Çıkan Başlıklar")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.gray)
                                
                                ForEach(news.keyHeadlines.prefix(3), id: \.self) { headline in
                                    HStack(alignment: .top, spacing: 6) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 6)
                                        Text(headline)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        
                    } else {
                        // --- VERİ YOK MODU ---
                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.gray)
                            Text("Bu hisse için analist veya haber verisi bulunamadı")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear { loadData() }
        }
    }
    
    // ... existing loadData ...
    private func loadData() {
        Task {
            if let data = try? await HermesAnalystEngine.shared.analyze(symbol: symbol, currentPrice: currentPrice) {
                await MainActor.run {
                    self.result = data
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    private func verdictColor(_ verdict: String) -> Color {
        if verdict.contains("AL") { return .green }
        if verdict.contains("Nötr") || verdict.contains("TUT") { return .yellow }
        return .orange
    }
    
    // Lite Mod Yardımcıları
    private func sentimentColor(_ sentiment: NewsSentiment) -> Color {
        switch sentiment {
        case .strongPositive, .weakPositive: return .green
        case .weakNegative, .strongNegative: return .red
        default: return .gray
        }
    }
    
    private func sentimentIcon(_ sentiment: NewsSentiment) -> String {
        switch sentiment {
        case .strongPositive, .weakPositive: return "arrow.up.right.circle.fill"
        case .weakNegative, .strongNegative: return "arrow.down.right.circle.fill"
        default: return "minus.circle.fill"
        }
    }
}

// MARK: - Yardımcı View'lar

struct MetricMiniCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: -  Universal BIST Modül Detay Kartı
// Backend'deki BistModuleResult verilerini direkt gösterir

struct BistModuleDetailCard: View {
    let moduleResult: BistModuleResult
    let moduleColor: Color
    let moduleIcon: String
    
    // Modüle özel ek bilgiler
    var extraInfo: [ExtraInfoItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1️⃣ HEADER: Skor + Aksiyon
            HStack {
                // Skor Gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    if moduleResult.score > 0 {
                        Circle()
                            .trim(from: 0, to: moduleResult.score / 100)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(Int(moduleResult.score))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor)
                            Text("/100")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    } else {
                        // Veri Yok Durumu
                        VStack(spacing: 0) {
                            Text("--")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            Text("Veri Yok")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Aksiyon Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("KARAR")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(actionText)
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(8)
                }
            }
            
            // 2️⃣ YORUM (Commentary) - Açıklama
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(moduleColor)
                    Text("Analiz Özeti")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                Text(moduleResult.commentary)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
            
            // 3️⃣ DESTEK SEVİYESİ (Support Meter)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Destek Seviyesi")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(supportText)
                        .font(.caption.bold())
                        .foregroundColor(supportColor)
                }
                
                // Support Bar (-1 to +1 visualized)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                        
                        // Center marker
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width / 2 - 1)
                        
                        // Support indicator
                        let normalizedSupport = (moduleResult.supportLevel + 1) / 2 // Convert -1...1 to 0...1
                        RoundedRectangle(cornerRadius: 4)
                            .fill(supportColor)
                            .frame(width: max(4, geo.size.width * normalizedSupport), height: 8)
                    }
                }
                .frame(height: 12)
                
                // Legend
                HStack {
                    Text("İTİRAZ")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.7))
                    Spacer()
                    Text("NÖTR")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("DESTEK")
                        .font(.system(size: 9))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            
            // 4️⃣ EK BİLGİLER (Varsa)
            if !extraInfo.isEmpty {
                Divider().background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Detay Metrikleri")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                    }
                    
                    ForEach(extraInfo) { info in
                        HStack {
                            Image(systemName: info.icon)
                                .foregroundColor(info.color)
                                .frame(width: 20)
                            Text(info.label)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(info.value)
                                .font(.caption.bold())
                                .foregroundColor(info.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    
    private var scoreColor: Color {
        if moduleResult.score >= 70 { return .green }
        if moduleResult.score >= 40 { return .yellow }
        return .red
    }
    
    private var actionText: String {
        switch moduleResult.action {
        case .buy: return " AL"
        case .sell: return " SAT"
        case .hold: return "⏸️ BEKLE"
        }
    }
    
    private var actionColor: Color {
        switch moduleResult.action {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        }
    }
    
    private var supportText: String {
        if moduleResult.supportLevel > 0.5 { return "Güçlü Destek" }
        if moduleResult.supportLevel > 0.1 { return "Hafif Destek" }
        if moduleResult.supportLevel > -0.1 { return "Nötr" }
        if moduleResult.supportLevel > -0.5 { return "Hafif İtiraz" }
        return "Güçlü İtiraz"
    }
    
    private var supportColor: Color {
        if moduleResult.supportLevel > 0.3 { return .green }
        if moduleResult.supportLevel > -0.3 { return .yellow }
        return .red
    }
}

// Extra Info Item for Module Details
struct ExtraInfoItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let color: Color
}

// MARK: -  Global Modül Detay Kartı
// CouncilDecision verilerini gösterir (Orion, Atlas, Aether, Hermes için)

struct GlobalModuleDetailCard: View {
    let moduleName: String
    let decision: CouncilDecision
    let moduleColor: Color
    let moduleIcon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1️⃣ HEADER: Net Destek + Aksiyon
            HStack {
                // Net Support Gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: max(0, decision.netSupport))
                        .stroke(supportColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(decision.netSupport * 100))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(supportColor)
                        Text("%")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Aksiyon Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("SİNYAL")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(actionText)
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(8)
                    
                    Text(decision.signalStrength)
                        .font(.caption2)
                        .foregroundColor(signalStrengthColor)
                }
            }
            
            // 2️⃣ WINNING PROPOSAL (Ana Öneri)
            if let proposal = decision.winningProposal {
                    VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(moduleColor)
                        Text("Kazanan Öneri")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    
                    Text(cleanReasoning(proposal.reasoning))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                }
            }
            
            // 3️⃣ OYLAMA DURUMU
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Oylama")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Onay: \(Int(decision.approveWeight * 100))% | Veto: \(Int(decision.vetoWeight * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Vote Bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // Approve
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * decision.approveWeight)
                        
                        // Veto
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width * decision.vetoWeight)
                        
                        // Neutral
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }
            
            // 4️⃣ VETO REASONS (Varsa)
            if !decision.vetoReasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Veto Gerekçeleri")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    
                    ForEach(decision.vetoReasons.prefix(3), id: \.self) { reason in
                        Text("• \(reason)")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // Helper to clean raw strings
    private func cleanReasoning(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "weak_positive", with: "Olumlu (Zayıf)")
            .replacingOccurrences(of: "strong_positive", with: "Güçlü Olumlu")
            .replacingOccurrences(of: "weak_negative", with: "Olumsuz (Zayıf)")
            .replacingOccurrences(of: "strong_negative", with: "Güçlü Olumsuz")
            .replacingOccurrences(of: "neutral", with: "Nötr")
    }
    
    // MARK: - Computed Properties
    
    private var supportColor: Color {
        if decision.netSupport >= 0.5 { return .green }
        if decision.netSupport >= 0.2 { return .yellow }
        return .red
    }
    
    private var actionText: String {
        switch decision.action {
        case .buy: return " AL"
        case .sell: return " SAT"
        case .hold: return "⏸️ BEKLE"
        }
    }
    
    private var actionColor: Color {
        switch decision.action {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        }
    }
    
    private var signalStrengthColor: Color {
        switch decision.signalStrength {
        case "GÜÇLÜ": return .green
        case "ZAYIF": return .orange
        default: return .gray
        }
    }
}

// Orion UI Bileşenleri OrionDetailView.swift'te tanımlı - duplikasyon kaldırıldı
// LinearGauge, StructureLinearMap, Sparkline → OrionDetailView.swift

