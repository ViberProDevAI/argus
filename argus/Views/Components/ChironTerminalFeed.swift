import SwiftUI

struct ChironTerminalFeed: View {
    let events: [ChironLearningEvent]
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Collapsible)
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(Theme.tint)
                    Text("SYSTEM INTELLIGENCE LOG")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.tint)
                    
                    if !events.isEmpty {
                        Text("• \(events.count) EVENTS")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(hex: "0a0e17"))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Feed Content
            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if events.isEmpty {
                            Text("NO SYSTEM LOGS RECORDED")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(20)
                        } else {
                            ForEach(events) { event in
                                FeedRow(event: event)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
                .frame(maxHeight: 300) // Limit height
                .background(Color(hex: "05080f"))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct FeedRow: View {
    let event: ChironLearningEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Column
            VStack {
                Image(systemName: iconFor(event.eventType))
                    .font(.system(size: 12))
                    .foregroundColor(colorFor(event.eventType))
                    .frame(width: 20, height: 20)
                    .background(colorFor(event.eventType).opacity(0.1))
                    .clipShape(Circle())
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            
            // Content Column
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.description)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(timeAgo(event.date))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Text("> " + event.reasoning)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata
                HStack(spacing: 8) {
                    if let symbol = event.symbol {
                        Text("Target: \(symbol)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text("CONF: \(Int(event.confidence * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(event.confidence > 0.7 ? .green : .orange)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 12)
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
    }
    
    func iconFor(_ type: ChironEventType) -> String {
        switch type {
        case .weightUpdate: return "slider.horizontal.3"
        case .ruleAdded: return "plus.circle"
        case .ruleRemoved: return "minus.circle"
        case .analysisCompleted: return "checkmark.circle"
        case .anomalyDetected: return "exclamationmark.triangle"
        case .forwardTest: return "lab.flask"
        }
    }
    
    func colorFor(_ type: ChironEventType) -> Color {
        switch type {
        case .weightUpdate: return .blue
        case .ruleAdded: return .green
        case .ruleRemoved: return .red
        case .analysisCompleted: return .purple
        case .anomalyDetected: return .orange
        case .forwardTest: return .pink
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
