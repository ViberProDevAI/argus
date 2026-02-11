import SwiftUI

struct AthenaLabView: View {
    // MARK: - Simulation State
    // Value Params
    @State private var peRatio: Double = 15.0
    @State private var pbRatio: Double = 2.0
    @State private var dividendYield: Double = 2.0
    
    // Quality Params
    @State private var roe: Double = 15.0 // Return on Equity approx
    @State private var netMargin: Double = 10.0
    @State private var debtToEquity: Double = 0.5
    
    // Momentum Params (Synth)
    @State private var rsi: Double = 50.0
    @State private var relStrength: Double = 5.0 // vs Market
    
    // Risk Params
    @State private var volatility: Double = 1.5 // ATR/Price %
    @State private var marketCapBillions: Double = 10.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Result Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Athena Faktör Analizi")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    AthenaFactorCard(result: simulatedResult)
                        .padding(.horizontal)
                }
                
                // 2. Value Factors
                LabSection(title: "Değer (Value)", color: .green) {
                    sliderRaw(label: "F/K Oranı (P/E)", value: $peRatio, range: 0...100, ideal: 15)
                    sliderRaw(label: "PD/DD (P/B)", value: $pbRatio, range: 0...10, ideal: 1.5)
                    sliderRaw(label: "Temettü Verimi %", value: $dividendYield, range: 0...10, ideal: 3.0)
                }
                
                // 3. Quality Factors
                LabSection(title: "Kalite (Quality)", color: .blue) {
                    sliderRaw(label: "Net Marj %", value: $netMargin, range: -20...50, ideal: 15)
                    sliderRaw(label: "Borç/Özkaynak", value: $debtToEquity, range: 0...5, ideal: 0.5)
                }
                
                // 4. Momentum Factors
                LabSection(title: "Momentum", color: .purple) {
                    sliderRaw(label: "RSI (14)", value: $rsi, range: 0...100, ideal: 50)
                    sliderRaw(label: "Relatif Güç %", value: $relStrength, range: -50...50, ideal: 10)
                }
                
                // 5. Risk / Size
                LabSection(title: "Risk & Büyüklük", color: .orange) {
                    sliderRaw(label: "Volatilite % (ATR)", value: $volatility, range: 0...10, ideal: 1.5)
                    sliderRaw(label: "Piyasa Değeri (Milyar $)", value: $marketCapBillions, range: 0.1...2000, ideal: 10)
                }
                
                // Reset
                Button(action: resetParams) {
                    Text("Varsayılanlara Dön")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.secondaryBackground)
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.vertical)
        }
        .navigationTitle("Athena Lab ")
        .background(Theme.background)
    }
    
    // MARK: - Simulation Logic
    private var simulatedResult: AthenaFactorResult {
        // Create Mock Data
        let _ = FinancialsData(
            symbol: "SIM", currency: "USD", lastUpdated: Date(),
            totalRevenue: 100, netIncome: 100 * (netMargin/100), totalShareholderEquity: 100 / (1 + debtToEquity), // Hacky math for D/E
            marketCap: marketCapBillions * 1_000_000_000,
            revenueHistory: [], netIncomeHistory: [],
            ebitda: 100, shortTermDebt: 0, longTermDebt: 100 * debtToEquity, // Debt
            operatingCashflow: 0, capitalExpenditures: 0,
            cashAndCashEquivalents: 50,
            peRatio: peRatio, forwardPERatio: peRatio, priceToBook: pbRatio,
            evToEbitda: 0, dividendYield: dividendYield/100, forwardGrowthEstimate: 10,
            targetMeanPrice: nil, targetHighPrice: nil, targetLowPrice: nil, recommendationMean: nil, numberOfAnalystOpinions: nil
        )
        
        // Mock Candles for Momentum? 
        // Athena matches Momentum using returns. 
        // I can bypass candles and create a "Mock" function in AthenaService?
        // Or I can just manually calculate the Sub-Scores here for display:
        
        // Actually, AthenaFactorResult structure is:
        // value, quality, momentum, risk, factor, style
        
        // Let's replicate Athena scoring logic LOCALLY here for the Lab, 
        // to avoid modifying the main Service or creating 200 dummy candles.
        // This is a "Simulator" after all.
        
        // 1. Value
        let v1 = score(peRatio, 15, 30, true)
        let v2 = score(pbRatio, 1.5, 4.0, true)
        let v3 = score(dividendYield, 2.0, 0.0, false)
        let vScore = (v1 * 0.4) + (v2 * 0.4) + (v3 * 0.2)
        
        // 2. Quality
        let q1 = score(netMargin, 15, 5, false)
        let q2 = score(debtToEquity, 1.0, 2.0, true)
        let qScore = (q1 * 0.5) + (q2 * 0.5)
        
        // 3. Momentum
        let m1 = score(rsi, 50, 30, false) // Simple approximation
        let m2 = score(relStrength, 0, -10, false)
        let mScore = (m1 * 0.4) + (m2 * 0.6)
        
        // 4. Risk / Size
        let r1 = score(volatility, 2.0, 5.0, true)
        let r2 = score(marketCapBillions, 10, 0.1, false) // Small cap penalty? Or linear?
        // Athena Risk is "Low Risk = High Score". P/E 30 bad.
        let rScore = (r1 * 0.6) + (r2 * 0.4)
        
        // Total
        // 30% Value, 30% Quality, 25% Momentum, 15% Risk
        let total = (vScore * 0.30) + (qScore * 0.30) + (mScore * 0.25) + (rScore * 0.15)
        
        return AthenaFactorResult(
            symbol: "SIM",
            date: Date(),
            valueFactorScore: vScore,
            qualityFactorScore: qScore,
            momentumFactorScore: mScore,
            sizeFactorScore: r2,  // Size factor based on market cap
            riskFactorScore: r1,  // Risk is now purely volatility based
            factorScore: total,
            styleLabel: localStyleLabel(v: vScore, q: qScore, m: mScore)
        )
    }
    
    private func localStyleLabel(v: Double, q: Double, m: Double) -> String {
        func w(_ s: Double, _ l: String, _ md: String, _ h: String) -> String {
            if s >= 70 { return h }
            else if s >= 40 { return md }
            else { return l }
        }
        return "Athena: \(w(v, "Expensive", "Fair", "Cheap")) + \(w(q, "Hype", "Solid", "Quality")) + \(w(m, "Weak", "Flat", "Mo."))"
    }
    
    private func score(_ val: Double, _ ideal: Double, _ bad: Double, _ inverse: Bool) -> Double {
        // Simple linear interpolation
        
        // If inverse (Low is good): Ideal 15, Bad 30. Val 20.
        // If Val > Bad (35), score 0.
        // If Val < Ideal (10), score 100 (or capped?)
        
        if inverse {
            // Lower is Better (usually, or Target is Better)
            // Example P/E: Ideal 15. Bad 30.
            // If < 15, 100.
            if val <= ideal { return 100 }
            if val >= bad { return 0 }
            return 100 * (1 - (val - ideal) / (bad - ideal))
        } else {
            // Higher is Better
            // Dividend: Ideal 3.0. Bad 0.0.
            if val >= ideal { return 100 }
            if val <= bad { return 0 }
            return 100 * ((val - bad) / (ideal - bad))
        }
    }
    
    private func resetParams() {
        withAnimation {
            peRatio = 15.0
            pbRatio = 2.0
            dividendYield = 2.0
            netMargin = 10.0
            debtToEquity = 0.5
            rsi = 50.0
            relStrength = 5.0
            volatility = 1.5
            marketCapBillions = 10.0
        }
    }
    
    // Helper UI
    private func sliderRaw(label: String, value: Binding<Double>, range: ClosedRange<Double>, ideal: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .bold()
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}

struct LabSection<Content: View>: View {
    let title: String
    let color: Color
    let content: Content
    
    init(title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
