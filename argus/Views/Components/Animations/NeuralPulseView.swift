import SwiftUI

struct NeuralPulseView: View {
    let color: Color
    
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 1)
                .scaleEffect(animate ? 1.5 : 1.0)
                .opacity(animate ? 0.0 : 0.5)
            
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 1)
                .scaleEffect(animate ? 2.0 : 1.0)
                .opacity(animate ? 0.0 : 0.3)
            
            Circle()
                .fill(color.opacity(0.1))
                .scaleEffect(0.8)
        }
        .onAppear {
            withAnimation(Animation.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                self.animate = true
            }
        }
    }
}
