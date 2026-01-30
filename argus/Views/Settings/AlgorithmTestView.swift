import SwiftUI

struct AlgorithmTestView: View {
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let status: Bool
        let message: String
        let value: String
    }
    
    var body: some View {
        List {
            Section(header: Text("Algoritma Doğrulama Testi")) {
                if isRunning {
                    ProgressView("Testler Çalışıyor...")
                } else {
                    Button("Testi Başlat") {
                        runTests()
                    }
                }
            }
            
            ForEach(testResults) { result in
                HStack {
                    Image(systemName: result.status ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.status ? .green : .red)
                    VStack(alignment: .leading) {
                        Text(result.name).bold()
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(result.value)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .navigationTitle("Sistem Kontrolü")
    }
    
    func runTests() {
        isRunning = true
        testResults = []
        
        DispatchQueue.global().async {
            // 1. Generate Synthetic Data (Uptrend)
            var candles: [Candle] = []
            var price = 100.0
            for i in 0..<100 {
                // Linear uptrend + Sine wave
                price += 1.0 + sin(Double(i) * 0.5) * 2.0
                let candle = Candle(
                    date: Date().addingTimeInterval(Double(i) * 86400),
                    open: price - 1,
                    high: price + 2,
                    low: price - 2,
                    close: price,
                    volume: 1000
                )
                candles.append(candle)
            }
            
            var results: [TestResult] = []
            let service = AnalysisService.shared
            
            // Test 1: RSI
            // In a strong uptrend, RSI should be high (> 50)
            // Note: calculateCompositeScore returns a score (-100 to 100), not the raw value.
            // We need to access private methods or infer from score.
            // For verification, let's use the public 'generateDetailedSignals' and parse values.
            
            let signals = service.generateDetailedSignals(candles: candles)
            
            // RSI Check
            if let rsiSignal = signals.first(where: { $0.strategyName.contains("RSI") }),
               let valStr = rsiSignal.indicatorValues["RSI"],
               let val = Double(valStr) {
                let pass = val > 50
                results.append(TestResult(name: "RSI Calculation", status: pass, message: "Yükseliş trendinde RSI > 50 olmalı", value: "\(val)"))
            } else {
                results.append(TestResult(name: "RSI Calculation", status: false, message: "Sinyal üretilemedi", value: "N/A"))
            }
            
            // SMA Check
            if let smaSignal = signals.first(where: { $0.strategyName.contains("SMA") }),
               let s20Str = smaSignal.indicatorValues["SMA20"],
               let s50Str = smaSignal.indicatorValues["SMA50"],
               let s20 = Double(s20Str),
               let s50 = Double(s50Str) {
                let pass = s20 > s50
                results.append(TestResult(name: "SMA Trend", status: pass, message: "Yükselişte SMA20 > SMA50 olmalı", value: "\(s20) > \(s50)"))
            }
            
            // MACD Check
            if let macdSignal = signals.first(where: { $0.strategyName.contains("MACD") }),
               let macdStr = macdSignal.indicatorValues["MACD"] {
                results.append(TestResult(name: "MACD Calculation", status: true, message: "Değer başarıyla hesaplandı (EMA bazlı)", value: macdStr))
            }
            
            // Bollinger Check
            if let bbSignal = signals.first(where: { $0.strategyName.contains("Bollinger") }),
               let upperStr = bbSignal.indicatorValues["Upper"],
               let lowerStr = bbSignal.indicatorValues["Lower"],
               let u = Double(upperStr),
               let l = Double(lowerStr) {
                let pass = u > l
                results.append(TestResult(name: "Bollinger Bands", status: pass, message: "Üst bant > Alt bant olmalı", value: "OK"))
            }
            
            // ADX Check (Now Deterministic)
            if let adxSignal = signals.first(where: { $0.strategyName.contains("ADX") }),
               let adxStr = adxSignal.indicatorValues["ADX"],
               let adx = Double(adxStr) {
                let pass = adx > 0 && adx < 100
                results.append(TestResult(name: "ADX Calculation", status: pass, message: "0-100 arasında geçerli değer", value: "\(adx)"))
            }
            
            DispatchQueue.main.async {
                self.testResults = results
                self.isRunning = false
            }
        }
    }
}
