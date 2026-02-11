import SwiftUI

/// Uygulama genelinde kullanılacak standart hata ekranı.
struct UnifiedErrorView: View {
    var title: String = "Bir Hata Oluştu"
    var message: String
    var retryAction: (() -> Void)?
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.large) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(DesignTokens.Colors.error)
                
                VStack(spacing: DesignTokens.Spacing.small) {
                    Text(title)
                        .font(DesignTokens.Fonts.headline)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(message)
                        .font(DesignTokens.Fonts.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let retry = retryAction {
                    Button(action: retry) {
                        Text("Tekrar Dene")
                            .font(DesignTokens.Fonts.title)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignTokens.Colors.primary)
                            .cornerRadius(DesignTokens.Radius.medium)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.large)
                }
            }
        }
    }
}

#Preview {
    UnifiedErrorView(message: "Bağlantı hatası oluştu.", retryAction: {})
}
