
import SwiftUI

// MARK: - Alkindus Avatar View
/// "Sarıklı Bilge" animasyonlu avatarı.
/// Tek çizgi sanatıyla tasarlanmış, şeffaf arka planlı.
/// Duruma göre renk değiştirir: Düşünürken (Sarı), Fikir Bulunca (Yeşil).
struct AlkindusAvatarView: View {
    var size: CGFloat = 60
    var isThinking: Bool = false
    var hasIdea: Bool = false
    
    @State private var animPhase: CGFloat = 0.0
    
    // Neon Colors
    private let neonBlue = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let neonPurple = Color(red: 0.8, green: 0.2, blue: 1.0)
    private let ideaGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    
    var activeColor: Color {
        if hasIdea { return ideaGreen }
        return isThinking ? neonPurple : neonBlue
    }
    
    var body: some View {
        ZStack {
            // 1. Glow Effect (Arka Plan)
            Circle()
                .fill(activeColor)
                .frame(width: size * 0.8, height: size * 0.8)
                .blur(radius: size * 0.5)
                .opacity(isThinking ? 0.3 + (Foundation.sin(animPhase) * 0.1) : 0.2)
            
            // 2. The Sage (Profil - Neon Line Art)
            SageShape()
                .trim(from: 0, to: isThinking ? 0.8 + (Foundation.sin(animPhase) * 0.1) : 1.0)
                .stroke(activeColor, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .shadow(color: activeColor, radius: 4)
            
            // 3. Brain/Idea Spark (Fikir varsa)
            if hasIdea {
                Circle()
                    .fill(ideaGreen)
                    .frame(width: size * 0.1, height: size * 0.1)
                    .offset(x: size * 0.1, y: -size * 0.2)
                    .blur(radius: 2)
                    .shadow(color: ideaGreen, radius: 5)
                    .scaleEffect(1.0 + (Foundation.sin(animPhase * 5) * 0.3))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                animPhase = .pi / 2
            }
        }
    }
}

// MARK: - VECTOR SHAPES

// MARK: - VECTOR SHAPES

/// Neo-Sage Shape (Tek Çizgi Sanatı - Neon Profil)
struct SageShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Tek bir sürekli çizgi ile profil ve sarık çizimi
        // Başlangıç: Ense / Sarık altı
        path.move(to: CGPoint(x: w * 0.75, y: h * 0.7))
        
        // Sarık arkası
        path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.2), 
                      control1: CGPoint(x: w * 0.9, y: h * 0.5), 
                      control2: CGPoint(x: w * 0.8, y: h * 0.2))
        
        // Sarık önü (Mistik kıvrım)
        path.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.45), 
                      control1: CGPoint(x: w * 0.4, y: h * 0.2), 
                      control2: CGPoint(x: w * 0.2, y: h * 0.35))
        
        // Alın ve Yüz Profili
        path.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.6), control: CGPoint(x: w * 0.35, y: h * 0.55))
        
        // Burun
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.68))
        
        // Düşünen El (Çene altında)
        path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.85), 
                      control1: CGPoint(x: w * 0.4, y: h * 0.8), 
                      control2: CGPoint(x: w * 0.5, y: h * 0.9))
        
        return path
    }
}

// "SageEyes" artık kullanılmıyor, tek çizgi sanatı olduğu için kaldırıldı.

// MARK: - Preview
struct AlkindusAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HStack(spacing: 30) {
                VStack {
                    Text("Idle").foregroundColor(.white)
                    AlkindusAvatarView(isThinking: false, hasIdea: false)
                }
                VStack {
                    Text("Thinking").foregroundColor(.white)
                    AlkindusAvatarView(isThinking: true, hasIdea: false)
                }
                VStack {
                    Text("Idea!").foregroundColor(.white)
                    AlkindusAvatarView(isThinking: false, hasIdea: true)
                }
            }
        }
    }
}
