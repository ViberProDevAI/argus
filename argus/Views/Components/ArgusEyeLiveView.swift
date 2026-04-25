import SwiftUI

struct ArgusEyeLiveView: View {
    // Animation States
    @State private var isRotatingOuter = false
    @State private var isRotatingInner = false
    @State private var isScanning = false
    @State private var isBreathing = false
    
    // Configuration
    var size: CGFloat = 200
    var showScanBeam: Bool = true
    
    var body: some View {
        ZStack {
            // 1. Base Glow (Atmosphere)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.clear]),
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.6
                    )
                )
                .scaleEffect(isBreathing ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isBreathing)
            
            // 2. The Mechanical Eye Core (Image)
            Image("ArgusMacroEye")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
                .clipShape(Circle())
                .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.cyan.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                )
            
            // 3. Inner Tech Ring (Rotating Clockwise)
            if showScanBeam {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .clear, .cyan.opacity(0.5), .clear]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 20])
                    )
                    .frame(width: size * 0.82, height: size * 0.82)
                    .rotationEffect(.degrees(isRotatingInner ? 360 : 0))
                    .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: isRotatingInner)
            }
            
            // 4. Outer Data Ring (Rotating Counter-Clockwise)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(colors: [.blue.opacity(0.8), .cyan.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .butt, dash: [5, 5])
                )
                .frame(width: size * 0.95, height: size * 0.95)
                .rotationEffect(.degrees(isRotatingOuter ? -360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isRotatingOuter)
            
            // 5. Radar Scan Beam ( The "Search" Effect)
            if showScanBeam {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [.clear, .cyan.opacity(0.2), .cyan.opacity(0.0)]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(90)
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(isScanning ? 360 : 0))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isScanning)
                    .blendMode(.screen)
            }
            
            // 6. Digital Glitch / Data Points
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 4, height: 4)
                            .opacity(isScanning ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.2).repeatForever().delay(Double.random(in: 0...0.5)), value: isScanning)
                    }
                }
                .padding(.bottom, size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            isRotatingOuter = true
            isRotatingInner = true
            isScanning = true
            isBreathing = true
        }
    }
}

// Preview to verify
struct ArgusEyeLiveView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ArgusEyeLiveView(size: 250)
        }
    }
}
