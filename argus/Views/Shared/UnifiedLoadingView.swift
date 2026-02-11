import SwiftUI

/// Uygulama genelinde kullanılacak standart yükleme ekranı.
struct UnifiedLoadingView: View {
    var message: String = "Yükleniyor..."
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(DesignTokens.Fonts.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    UnifiedLoadingView()
}
