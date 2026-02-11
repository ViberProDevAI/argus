import SwiftUI

/// A futuristic, stylized Eye/Triangle shape representing Argus.
/// Designed for "Stroke Animation" (drawing with .trim).
struct ArgusLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Triangle Points
        // Top Center
        let topPoint = CGPoint(x: width * 0.5, y: height * 0.1)
        // Bottom Right
        let bottomRightPoint = CGPoint(x: width * 0.9, y: height * 0.85)
        // Bottom Left
        let bottomLeftPoint = CGPoint(x: width * 0.1, y: height * 0.85)
        
        // Eye Center
        let eyeCenter = CGPoint(x: width * 0.5, y: height * 0.55)
        let eyeRadius = width * 0.12
        
        // MARK: - The Triangle (Outer Frame)
        
        // Start from top, go slightly down to allow open-top effect or full close
        path.move(to: topPoint)
        path.addLine(to: bottomRightPoint)
        path.addLine(to: bottomLeftPoint)
        path.closeSubpath()
        
        // MARK: - The Eye (Inner Vision)
        // Draw the pupil/iris as a separate subpath for cool effects
        // We simulate a "Cyber Eye" - not just a circle, but a split circle
        
        // Top half of the eye
        path.move(to: CGPoint(x: eyeCenter.x - eyeRadius, y: eyeCenter.y))
        path.addQuadCurve(
            to: CGPoint(x: eyeCenter.x + eyeRadius, y: eyeCenter.y),
            control: CGPoint(x: eyeCenter.x, y: eyeCenter.y - eyeRadius * 1.5)
        )
        
        // Bottom half of the eye
        path.move(to: CGPoint(x: eyeCenter.x - eyeRadius, y: eyeCenter.y))
        path.addQuadCurve(
            to: CGPoint(x: eyeCenter.x + eyeRadius, y: eyeCenter.y),
            control: CGPoint(x: eyeCenter.x, y: eyeCenter.y + eyeRadius * 1.5)
        )
        
        // The Pupil (Core)
        let pupilRect = CGRect(
            x: eyeCenter.x - eyeRadius * 0.3,
            y: eyeCenter.y - eyeRadius * 0.3,
            width: eyeRadius * 0.6,
            height: eyeRadius * 0.6
        )
        path.addEllipse(in: pupilRect)
        
        return path
    }
}

struct ArgusLogoShape_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ArgusLogoShape()
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 200, height: 200)
                .shadow(color: .cyan, radius: 10)
        }
    }
}
