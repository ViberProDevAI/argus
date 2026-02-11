import SwiftUI

// MARK: - Liquid Effect View
/// Jiroskopa duyarlı, "sıvı cam" efekti.
/// Arka planda süzülen neon kabarcıklar.
struct LiquidEffectView: View {
    @StateObject private var motion = LiquidMotionManager()
    var color: Color = Theme.tint // Varsayılan renk (BIST için kırmızı olacak)
    var intensity: Double = 1.0   // Efekt yoğunluğu
    
    // Kabarcık Konfigürasyonu
    struct Bubble: Identifiable {
        let id = UUID()
        var size: CGFloat
        var x: CGFloat
        var y: CGFloat
        var blur: CGFloat
        var opacity: Double
        var speed: Double
    }
    
    // Rastgele Kabarcıklar (Statik başlangıç, Motion ile hareket edecekler)
    @State private var bubbles: [Bubble] = (0..<12).map { _ in
        Bubble(
            size: CGFloat.random(in: 40...180),
            x: CGFloat.random(in: -0.5...1.5), // Ekran genişliğine oranla
            y: CGFloat.random(in: -0.5...1.5),
            blur: CGFloat.random(in: 20...60),
            opacity: Double.random(in: 0.1...0.3),
            speed: Double.random(in: 0.5...1.5)
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Derin Arka Plan (Gradient)
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.15 * intensity),
                        Color.black.opacity(0.8)
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                // Kabarcık Katmanı
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(color)
                        .frame(width: bubble.size, height: bubble.size)
                        .blur(radius: bubble.blur)
                        .opacity(bubble.opacity * intensity)
                        .position(
                            x: (geo.size.width * bubble.x) + (CGFloat(motion.roll * 50 * bubble.speed)), // Gyro hareketi
                            y: (geo.size.height * bubble.y) + (CGFloat(motion.pitch * 50 * bubble.speed))
                        )
                        // Hafif "Nefes Alma" animasyonu
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.1), lineWidth: 1)
                                .scaleEffect(1.2)
                                .opacity(0.5)
                        )
                }
                
                // Cam Örtüsü (Glass Overlay)
                // Kabarcıkların önünde, içeriğin arkasında durur.
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                    .opacity(0.3)
                    .ignoresSafeArea()
            }
        }
        .drawingGroup() // Performans optimizasyonu (Metal Render)
    }
}

// MARK: - Preview
struct LiquidEffect_Preview: PreviewProvider {
    static var previews: some View {
        LiquidEffectView(color: .blue, intensity: 1.0)
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
        
        LiquidEffectView(color: .red, intensity: 1.0) // BIST Modu
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
    }
}
