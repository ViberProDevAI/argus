import SwiftUI

struct ArgusAthenaSheet: View {
    let result: AthenaFactorResult?
    let signals: [ChimeraSignal]  // Chimera Smart Signals
    @Environment(\.presentationMode) var presentationMode
    
    init(result: AthenaFactorResult?, signals: [ChimeraSignal] = []) {
        self.result = result
        self.signals = signals
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.teal)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Athena Faktor Analizi")
                            .font(.headline)
                        Text("Smart Beta & Strateji")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Theme.secondaryBackground)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // CHIMERA SMART SIGNALS (YENİ)
                        if !signals.isEmpty {
                            AthenaCard(signals: signals)
                                .padding(.top)
                        }
                        
                        if let result = result {
                            // 1. Main Card Reuse
                            AthenaFactorCard(result: result)
                                .padding(.top)
                            
                            // 2. Explanation / Insight
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Analiz Ozeti")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Text(generateExplanation(for: result))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                            
                            // 3. Definitions
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Faktor Tanimlari")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                definitionRow(title: "Deger (Value)", desc: "Hissenin fiyatinin kazanc ve varliklarina gore ucuzlugunu olcer.")
                                definitionRow(title: "Kalite (Quality)", desc: "Sirketin karlilik, borcluluk ve yonetim kalitesini olcer.")
                                definitionRow(title: "Momentum", desc: "Fiyatin yukselis trendi ve gucunu olcer.")
                                definitionRow(title: "Risk (Low Vol)", desc: "Fiyat hareketlerindeki dalgalanma ve istikrari olcer.")
                            }
                            .padding(.bottom, 40)
                        } else if signals.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                                Text("Analiz verisi bulunamadi.")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func definitionRow(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.teal)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private func generateExplanation(for result: AthenaFactorResult) -> String {
        return "Athena, bu hisse için \(Int(result.factorScore))/100 puan hesapladı. " +
        "Strateji etiketi: '\(result.styleLabel)'. " +
        "Ağırlıklı olarak \(highestFactor(result)) faktörü öne çıkıyor."
    }
    
    private func highestFactor(_ r: AthenaFactorResult) -> String {
        let factors = [
            ("Değer", r.valueFactorScore),
            ("Kalite", r.qualityFactorScore),
            ("Momentum", r.momentumFactorScore),
            ("Risk", r.riskFactorScore)
        ]
        return factors.max(by: { $0.1 < $1.1 })?.0 ?? "Dengeli"
    }
}
