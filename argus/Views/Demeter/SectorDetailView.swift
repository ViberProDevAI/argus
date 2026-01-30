import SwiftUI

struct SectorDetailView: View {
    let score: DemeterScore
    @Environment(\.presentationMode) var presentationMode
    
    // New: LLM Support
    @State private var llmInsight: String?
    @State private var isLoadingLLM = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Header
                        VStack(spacing: 8) {
                            Text(score.sector.name)
                                .font(.title3)
                                .foregroundStyle(.gray)
                            Text(score.sector.rawValue)
                                .font(.system(size: 40, weight: .bold))
                            
                            HStack {
                                Text("Skor:")
                                Text(String(format: "%.0f", score.totalScore))
                                    .font(.title2.bold())
                                    .foregroundStyle(Color(score.colorName))
                                Text("(\(score.grade))")
                                    .font(.title3)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.top)
                        
                        // 2. Metrics Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricCard(title: "Momentum", value: String(format: "%.0f", score.momentumScore), color: .blue)
                            MetricCard(title: "Şok Etkisi", value: String(format: "%.0f", score.shockImpactScore), color: score.shockImpactScore < 50 ? .red : .green)
                            MetricCard(title: "Rejim Uyumu", value: String(format: "%.0f", score.regimeScore), color: .purple)
                            MetricCard(title: "Rel. Strength", value: String(format: "%.0f", score.breadthScore), color: .orange)
                        }
                        
                        // 3. Driver/Shock Breakdown
                        if !score.driverContributions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sürücü Analizi (Puan Etkisi)")
                                    .font(.headline)
                                
                                ForEach(score.driverContributions.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                                    HStack {
                                        Text(key)
                                        Spacer()
                                        Text(value > 0 ? "+\(String(format: "%.1f", value))" : "\(String(format: "%.1f", value))")
                                            .foregroundStyle(value > 0 ? .green : .red)
                                            .bold()
                                    }
                                    Divider()
                                }
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(12)
                        } else {
                            Text("Şok etkisi nötr.")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        
                        // 4. Advice / Analysis
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Demeter Analizi", systemImage: "text.quote")
                                    .font(.caption.bold())
                                    .foregroundStyle(.gray)
                                Spacer()
                                if isLoadingLLM {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else if llmInsight == nil {
                                    Button(action: {
                                        Task {
                                            isLoadingLLM = true
                                            llmInsight = await ArgusVoiceService.shared.generateDemeterInsight(score: score)
                                            isLoadingLLM = false
                                        }
                                    }) {
                                        Text("Gemini ile Detaylandır ✨")
                                            .font(.caption.bold())
                                            .foregroundStyle(Theme.tint)
                                    }
                                }
                            }
                            
                            if let insight = llmInsight {
                                Text(insight)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .padding()
                                    .background(insight.starts(with: "Analiz oluşturulamadı") ? Color.red.opacity(0.1) : Theme.secondaryBackground)
                                    .foregroundColor(insight.starts(with: "Analiz oluşturulamadı") ? .red : .primary)
                                    .cornerRadius(8)
                                    .transition(.opacity)
                            } else {
                                Text(score.advice)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Detay Analiz")
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
}
