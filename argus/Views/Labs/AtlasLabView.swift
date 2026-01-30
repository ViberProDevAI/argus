import SwiftUI

struct AtlasLabView: View {
    // MARK: - Simulation State
    @State private var totalScore: Double = 50.0
    
    // Sliders mimicking FundamentalScoreEngine categories
    @State private var profitability: Double = 50.0
    @State private var growth: Double = 50.0
    @State private var cash: Double = 50.0
    @State private var debt: Double = 50.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Result Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Atlas Temel Analiz")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    LabResultCard(title: "Atlas Skor", score: simulatedResult.totalScore)
                        .padding(.horizontal)
                }
                
                // 2. Control Layout
                LabSection(title: "Karlılık (Profitability)", color: .green) {
                    sliderRaw(label: "Net Marj & ROE Skoru", value: $profitability)
                }
                
                LabSection(title: "Büyüme (Growth)", color: .blue) {
                    sliderRaw(label: "Gelir & Kar Büyüme Skoru", value: $growth)
                }
                
                LabSection(title: "Nakit (Cash)", color: .purple) {
                    sliderRaw(label: "Nakit Akışı Skoru", value: $cash)
                }
                
                LabSection(title: "Borçluluk (Debt)", color: .red) {
                    sliderRaw(label: "Borç Yönetim Skoru", value: $debt)
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
            }
            .padding(.vertical)
        }
        .navigationTitle("Atlas Lab 🗺️")
        .background(Theme.background)
    }
    
    private var simulatedResult: FundamentalScoreResult {
        // Weighted Average (Atlas Logic: 30% Prof, 30% Growth, 20% Debt, 20% Cash)
        let total = (profitability * 0.3) + (growth * 0.3) + (debt * 0.2) + (cash * 0.2)
        
        return FundamentalScoreResult(
            symbol: "SIM",
            date: Date(),
            totalScore: total,
            realizedScore: total,
            forwardScore: total,
            profitabilityScore: profitability,
            growthScore: growth,
            leverageScore: debt,
            cashQualityScore: cash,
            dataCoverage: 100.0,
            summary: "Simulated Data for Atlas Lab",
            highlights: [],
            proInsights: [],
            calculationDetails: "Simulated",
            valuationGrade: "Makul",
            riskScore: 50.0,
            financials: nil
        )
    }
    
    private func resetParams() {
        withAnimation {
            profitability = 50
            growth = 50
            cash = 50
            debt = 50
        }
    }
    
    private func sliderRaw(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .bold()
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.caption)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...100)
        }
    }
}

// Local Helper
struct LabResultCard: View {
    let title: String
    let score: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(scoreColor(score).opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Text(String(format: "%.0f", score))
                    .font(.title3)
                    .bold()
                    .foregroundColor(scoreColor(score))
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func scoreColor(_ s: Double) -> Color {
        if s >= 70 { return .green }
        if s >= 50 { return .yellow }
        return .red
    }
}
