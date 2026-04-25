import SwiftUI

struct EarningsBadgeView: View {
    let daysUntil: Int?
    
    var body: some View {
        if let days = daysUntil {
            HStack(spacing: 4) {
                Image(systemName: iconName(days: days))
                    .font(.caption)
                Text(text(days: days))
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor(days: days).opacity(0.2))
            .foregroundColor(backgroundColor(days: days))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(backgroundColor(days: days).opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func iconName(days: Int) -> String {
        if days < 0 { return "calendar.badge.minus" } // Past
        if days <= 5 { return "exclamationmark.triangle.fill" } // Verify Danger
        return "calendar"
    }
    
    private func text(days: Int) -> String {
        if days < 0 {
            return "Raporlandı (\(abs(days))g önce)"
        } else if days == 0 {
            return "BUGÜN"
        } else {
            return "\(days) Gün Kaldı"
        }
    }
    
    private func backgroundColor(days: Int) -> Color {
        if days < 0 { return .gray }
        if days <= 5 { return .red } // Danger Zone
        if days <= 14 { return .orange } // Warning
        return .green // Safe
    }
}

#Preview {
    EarningsBadgeView(daysUntil: 3)
}
