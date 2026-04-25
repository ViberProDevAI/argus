import SwiftUI

struct RoadmapView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Static Roadmap Data (mirroring task.md future section)
    let milestones: [RoadmapItem] = [
        RoadmapItem(
            title: "Veri Güvenliği ve Geçmiş",
            description: "Geriye dönük Atlas verileri ile backtest'in 'Static Bias' hatasından arındırılması.",
            status: .planned,
            quarter: "Q1 2026"
        ),
        RoadmapItem(
            title: "Rejim Analizi Paneli",
            description: "Risk-On vs Risk-Off durumlarında strateji başarısını ölçen 'Success by Regime' paneli.",
            status: .planned,
            quarter: "Q1 2026"
        ),
        RoadmapItem(
            title: "Sürüm Kontrolü (v1.x)",
            description: "Ağırlık setleri (Weight Sets) için versiyonlama. Öncesi/Sonrası performans kıyaslaması.",
            status: .planned,
            quarter: "Q2 2026"
        ),
        RoadmapItem(
            title: "Tam Otonom Ticaret",
            description: "Kullanıcı onayı olmadan, belirlenen risk limitleri dahilinde tam otomatik alım-satım yetkisi.",
            status: .concept,
            quarter: "Q3 2026"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "GELECEK VİZYONU",
                subtitle: "YOL HARİTASI · KİLOMETRE TAŞLARI",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [.custom(sfSymbol: "xmark", action: { presentationMode.wrappedValue.dismiss() })]
            )
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Intro
                        VStack(alignment: .leading, spacing: 6) {
                            ArgusSectionCaption("ARGUS · EVRİM")
                            Text("Argus Sisteminin Gelişim Yol Haritası")
                                .font(.body)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Milestones
                        VStack(spacing: 0) {
                            ForEach(Array(milestones.enumerated()), id: \.offset) { index, item in
                                RoadmapRow(item: item, isLast: index == milestones.count - 1)
                            }
                        }
                        .padding()

                        // Note
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Not")
                                .font(.headline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Text("Bu yol haritası piyasa koşullarına ve teknik gereksinimlere göre güncellenebilir. 'AI Öğrenme Günlüğü' üzerinden sistemin bu hedeflere doğru nasıl evrildiğini takip edebilirsiniz.")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .padding()
                                .background(InstitutionalTheme.Colors.surface1)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct RoadmapItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let status: RoadmapStatus
    let quarter: String
}

enum RoadmapStatus {
    case completed
    case inProgress
    case planned
    case concept
    
    var color: Color {
        switch self {
        case .completed: return .green
        case .inProgress: return .blue
        case .planned: return .orange
        case .concept: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath.circle.fill"
        case .planned: return "circle.dashed"
        case .concept: return "lightbulb.fill"
        }
    }
}

struct RoadmapRow: View {
    let item: RoadmapItem
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline Line & Dot
            VStack(spacing: 0) {
                Image(systemName: item.status.icon)
                    .foregroundColor(item.status.color)
                    .background(InstitutionalTheme.Colors.background) // Hide line behind icon
                    .zIndex(1)
                
                if !isLast {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.border)
                        .frame(width: 2)
                        .frame(minHeight: 60)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                    Text(item.quarter)
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.status.color.opacity(0.2))
                        .foregroundColor(item.status.color)
                        .cornerRadius(8)
                }
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true) // Wrap text
                    .padding(.bottom, 24)
            }
        }
    }
}
