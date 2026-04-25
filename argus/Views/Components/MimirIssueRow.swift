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
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("\(issue.engine.rawValue) • \(issue.asset)")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
