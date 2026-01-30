import SwiftUI

struct OrionLabView: View {
    @StateObject private var viewModel = OrionLabViewModel()
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text("İstatistikler hesaplanıyor...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else if viewModel.gradeStats.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Henüz Veri Yok")
                        .font(.headline)
                    Text("Uygulama Orion skorları üretmeye devam ettikçe burada performansları görebileceksiniz.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    Section(header: Text("Performans Karnesi")) {
                        ForEach(viewModel.gradeStats) { stat in
                            HStack {
                                // Grade Circle
                                ZStack {
                                    Circle()
                                        .fill(colorForGrade(stat.letter).opacity(0.2))
                                        .frame(width: 48, height: 48)
                                    
                                    VStack(spacing: 0) {
                                            // Empty for now (grade removed)
                                        Text("\(stat.count) kayıt")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Stats
                                VStack(alignment: .trailing, spacing: 4) {
                                    HStack {
                                        Text("Ort. 5 Gün:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatPercent(stat.avgReturn5D))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(colorForReturn(stat.avgReturn5D))
                                    }
                                    
                                    HStack {
                                        Text("5 Gün İsabet:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatPercent(stat.hitRate5D, isRate: true))
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(colorForHitRate(stat.hitRate5D))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section(footer: Text("Bu tablo, Argus Orion sinyallerinin geçmiş performansını özetler. Zamanla yeni veriler geldikçe güncellenir. Yatırım tavsiyesi değildir.")) {
                        EmptyView()
                    }
                }
            }
        }
        .navigationTitle("Argus Orion Lab")
        .task {
            viewModel.loadStats()
        }
    }
    
    // MARK: - Helpers
    
    private func formatPercent(_ value: Double?, isRate: Bool = false) -> String {
        guard let v = value else { return "-" }
        if isRate {
            return String(format: "%%%.0f", v)
        } else {
            return String(format: "%+.1f%%", v)
        }
    }
    
    private func colorForGrade(_ letter: String) -> Color {
        switch letter {
        case "A+", "A", "A-": return .green
        case "B+", "B", "B-": return .blue
        case "C+", "C", "C-": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }
    
    private func colorForReturn(_ value: Double?) -> Color {
        guard let v = value else { return .primary }
        return v > 0 ? .green : (v < 0 ? .red : .gray)
    }
    
    private func colorForHitRate(_ value: Double?) -> Color {
        guard let v = value else { return .primary }
        return v >= 60 ? .green : (v < 40 ? .red : .primary)
    }
}
