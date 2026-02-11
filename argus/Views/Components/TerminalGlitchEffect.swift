import SwiftUI

struct TerminalGlitchEffect: ViewModifier {
    let originalText: String
    let progress: Double // 0.0 to 1.0
    
    // Characters to use for the glitch effect
    private let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%&*"
    
    func body(content: Content) -> some View {
        Text(scramble(text: originalText, progress: progress))
            .fixedSize() // Prevent layout jumping
    }
    
    private func scramble(text: String, progress: Double) -> String {
        if progress >= 1.0 { return text }
        
        return text.map { char in
            // If char is space, keep it
            if char == " " { return " " }
            
            // Probability of showing real character increases with progress
            if Double.random(in: 0...1) < progress {
                return String(char)
            } else {
                // Return random glitch char
                return String(chars.randomElement() ?? "?")
            }
        }.joined()
    }
}

extension View {
    func terminalGlitch(text: String, progress: Double) -> some View {
        self.modifier(TerminalGlitchEffect(originalText: text, progress: progress))
    }
}
