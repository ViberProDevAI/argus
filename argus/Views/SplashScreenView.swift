import SwiftUI

struct SplashScreenView: View {
    @Binding var isAppReady: Bool // Controls app launch state
    @State private var opacity: Double = 0.0
    @State private var taglineOpacity: Double = 0.0
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Premium Dark Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // 1. Brand Name - Minimal & Bold
                VStack(spacing: 8) {
                    Text("ARGUS")
                        .font(.custom("HelveticaNeue-Bold", size: 48))
                        .foregroundColor(.white)
                        .tracking(10) // Elegant wide spacing
                        .opacity(opacity)
                        .scaleEffect(opacity) // Subtle scale with fade
                    
                    Text("YATIRIM KONSEYİ")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(4)
                        .opacity(taglineOpacity)
                }
                
                // 2. Loading Indicator (Minimal Line)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 4)
                    
                    Capsule()
                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 200 * progress, height: 4)
                }
                .opacity(taglineOpacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // 1. Argus Fade In
        withAnimation(.easeOut(duration: 1.0)) {
            opacity = 1.0
        }
        
        // 2. Tagline Fade In
        withAnimation(.easeIn(duration: 0.8).delay(0.6)) {
            taglineOpacity = 1.0
        }
        
        // 3. Progress Bar Fill
        withAnimation(.easeInOut(duration: 1.5).delay(0.6)) {
            progress = 1.0
        }
        
        // 4. Clean Exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
             withAnimation(.easeOut(duration: 0.5)) {
                 opacity = 0.0
                 taglineOpacity = 0.0
             }
            
            // Hand over control
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAppReady = true
            }
        }
    }
}
