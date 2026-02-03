import SwiftUI

/// Pulsing Floating Action Button for Argus Voice
struct PulsingFABView: View {
    @State private var isPulsing = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(DesignTokens.Colors.primary, lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .opacity(isPulsing ? 0 : 0.6)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)

                // Middle ring
                Circle()
                    .stroke(DesignTokens.Colors.primary, lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                    .opacity(0.3)

                // Inner button
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primary)
                        .frame(width: 56, height: 56)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            }
            .shadow(color: DesignTokens.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 4)
        }
        .onAppear {
            startPulsing()
        }
    }

    private func startPulsing() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PulsingFABView()
    }
}
