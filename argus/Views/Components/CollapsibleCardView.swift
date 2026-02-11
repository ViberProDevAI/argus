import SwiftUI

struct CollapsibleCardView<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: AnyView?
    // iconColor is now only used if the icon is created via the string init internally or if needed elsewhere, 
    // but the AnyView stores the color itself if pre-configured.
    @State private var isExpanded: Bool = false
    let content: Content
    
    // Init for Custom View Icon
    init(
        title: String,
        subtitle: String? = nil,
        icon: AnyView? = nil,
        isExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }
    
    // Init for System Image Icon (Backwards Compatibility)
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = .blue,
        isExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        if let iconName = icon {
            self.icon = AnyView(
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            )
        } else {
            self.icon = nil
        }
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Always Visible)
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        icon
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        if let sub = subtitle, !isExpanded {
                            Text(sub)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
                .background(Theme.secondaryBackground)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content (Collapsible)
            if isExpanded {
                Divider()
                content
                    .padding()
                    .background(Theme.secondaryBackground)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
