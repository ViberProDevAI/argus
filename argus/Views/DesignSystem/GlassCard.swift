import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var brightness: Double // To adjust glass transparency/tint lightness
    
    init(cornerRadius: CGFloat = 16, brightness: Double = 0.0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.brightness = brightness
    }
    
    var body: some View {
        ZStack {
            // 1. Frosted Glass Base
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(0.9) // Make it substantial
            
            // 2. Tint Overlay (Darkening or Lightening)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Theme.cardBackground.opacity(0.4 + brightness))
            
            // 3. Border (The "Tech" Edge)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.2),
                            .white.opacity(0.05),
                            .white.opacity(0.05),
                            .white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // 4. Content
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Optional: Subtle Glow Shadow
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// Convenience Extension for Modifiers
extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        GlassCard(cornerRadius: cornerRadius) {
            self
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Text("Argus Glass System")
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .glassCard()
                .frame(width: 300, height: 100)
        }
    }
}
