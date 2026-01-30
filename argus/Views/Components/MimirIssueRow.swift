import SwiftUI

struct MimirIssueRow: View {
    let issue: MimirIssue
    
    var color: Color {
        switch issue.status {
        case "LOCKED": return .red
        case "MISSING": return .orange
        case "STALE": return .yellow
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(issue.description)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                Text("\(issue.engine.rawValue) • \(issue.asset)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
