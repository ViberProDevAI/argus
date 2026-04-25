import SwiftUI

struct ProvenanceBadgeView: View {
    let provenance: DataProvenance
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(provenance.source)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    var iconName: String {
        switch provenance.source {
        case "Yahoo": return "y.square.fill"
        case "FRED": return "building.columns.fill"
        case "Mimir": return "brain.head.profile"
        case "Cache": return "clock.arrow.circlepath"
        default: return "network"
        }
    }
    
    var color: Color {
        switch provenance.source {
        case "Yahoo": return .purple
        case "FRED": return .blue
        case "Mimir": return .pink
        case "Cache": return .gray
        default: return .secondary
        }
    }
}
