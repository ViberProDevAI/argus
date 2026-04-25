import SwiftUI

/// Frosted glass effect modifier inspired by Bloomberg Terminal
struct GlassmorphismModifier: ViewModifier {
    var opacity: Double = 0.15
    var blur: CGFloat = 10
    var borderOpacity: Double = 0.2

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(opacity))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
                    )
            )
            .backdrop(blur: blur)
    }
}

// Backdrop blur effect
struct BackdropBlurModifier: ViewModifier {
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                // UIVisualEffectView for native blur
                VisualEffectView(effect: UIBlurEffect(style: .dark))
                    .ignoresSafeArea()
            )
    }
}

// SwiftUI wrapper for UIVisualEffectView
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

extension View {
    func glassmorphism(opacity: Double = 0.15, blur: CGFloat = 10, borderOpacity: Double = 0.2) -> some View {
        modifier(GlassmorphismModifier(opacity: opacity, blur: blur, borderOpacity: borderOpacity))
    }

    func backdrop(blur: CGFloat = 10) -> some View {
        modifier(BackdropBlurModifier(blur: blur))
    }
}
