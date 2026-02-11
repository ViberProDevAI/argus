import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showVoiceSheet: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Bar Background & Items
            HStack {
                // Left Side
                TabBarButton(icon: "chart.bar.xaxis", text: "Piyasa", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                Spacer()
                
                // Tab 1: KOKPİT (Atlas + Radar + Lab)
                TabBarButton(icon: "airplane.circle", text: "Kokpit", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                // Center Space for Floating Button
                Spacer().frame(width: 80)
                
                TabBarButton(icon: "briefcase.fill", text: "Portföy", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                
                Spacer()
                
                TabBarButton(icon: "gearshape.fill", text: "Ayarlar", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 38) // Home Indicator padding
            .background(
                TabShape()
                    .fill(Theme.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: -5)
            )
            
            // Floating Button (Chiron / Voice)
            // ZStack placement ensures it's above and receives touches
            Button(action: { showVoiceSheet = true }) {
                ZStack {
                    Circle()
                        .fill(Theme.tint)
                        .frame(width: 60, height: 60) // Slightly larger for better touch target
                        .shadow(color: Theme.tint.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -50) // Lifted up to float
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Theme.tint : .gray)
                
                Text(text)
                    .font(.caption2)
                    .foregroundColor(isSelected ? Theme.tint : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Custom Shape for the "Hollow" effect
struct TabShape: Shape {
    func path(in rect: CGRect) -> Path {
        return TabShape.createNotchedPath(in: rect)
    }
    
    static func createNotchedPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = rect.width / 2
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: center - 50, y: 0))
        
        // Curve down
        path.addQuadCurve(
            to: CGPoint(x: center + 50, y: 0),
            control: CGPoint(x: center, y: 55)
        )
        
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// Helper extension for Shape to work simpler
extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
