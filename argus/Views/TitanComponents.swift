import SwiftUI

// MARK: - 1. Titan Analysis Card (Score + Context)
struct TitanAnalysisCard: View {
    let result: ArgusEtfEngine.TitanResult
    
    var ringColor: Color {
        let score = result.score
        if score >= 70 { return Theme.positive } // Green
        if score <= 30 { return Theme.negative } // Red
        return .yellow // Neutral
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Titan Analizi ⚡️")
                    .font(.headline)
                    .foregroundColor(Theme.tint)
                Spacer()
                Text(result.log.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            HStack(spacing: 20) {
                // Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: result.score / 100.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(result.score))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Puan")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 80, height: 80)
                
                // Context List
                VStack(alignment: .leading, spacing: 8) {
                    ContextRow(icon: "chart.line.uptrend.xyaxis", title: "Trend:", value: result.log.technicalContext, color: Theme.textPrimary)
                    ContextRow(icon: "globe", title: "Makro:", value: result.log.macroContext, color: Theme.textPrimary)
                    ContextRow(icon: "shazam.logo", title: "Kalite:", value: result.log.qualityContext, color: Theme.textSecondary)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ringColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ContextRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Theme.tint)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.caption)
                .bold()
                .foregroundColor(color)
        }
    }
}

// MARK: - 2. Fund Profile Card (Grid)
struct FundProfileCard: View {
    let profile: ETFProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fon Profili ")
                .font(.headline)
                .foregroundColor(.white)
            
            if let p = profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ProfileItem(label: "Sektör", value: p.sector ?? "-")
                    ProfileItem(label: "Yönetim Ücreti", value: p.expenseRatio != nil ? String(format: "%.2f%%", p.expenseRatio!) : "N/A")
                    ProfileItem(label: "Bölge", value: p.domicile ?? "Global")
                    ProfileItem(label: "Varlık Tipi", value: "ETF")
                }
                
                if !p.description.isEmpty {
                    Text(p.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .padding(.top, 8)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
}

struct ProfileItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
        }
    }
}

// ArgusEtfDetailView moved to ArgusEtfDetailView.swift
