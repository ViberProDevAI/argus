import SwiftUI

struct ArgusAdvisorsView: View {
    let advisors: [AdvisorNote]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Konsey Danışmanları")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
            
            if advisors.isEmpty {
                Text("Danışman verisi yok.")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            } else {
                ForEach(advisors) { note in
                    AdvisorRow(note: note)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AdvisorRow: View {
    let note: AdvisorNote
    
    var icon: String {
        switch note.module {
        case "Athena": return "brain.head.profile"
        case "Demeter": return "leaf.fill"
        case "Chiron": return "graduationcap.fill"
        default: return "person.fill"
        }
    }
    
    var color: Color {
        switch note.tone {
        case .positive: return .green
        case .caution: return .yellow
        case .warning: return .red
        case .neutral: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(note.module)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(note.advice)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
