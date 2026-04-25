import SwiftUI
import LocalAuthentication

struct SecureViewModifier: ViewModifier {
    @ObservedObject var security = SecurityService.shared
    let reason: String
    
    func body(content: Content) -> some View {
        Group {
            if security.isLocked {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                    
                    Text("Argus Kilitli")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Bu alana erişmek için kimlik doğrulaması gerekiyor.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        authenticate()
                    }) {
                        Label("Kilidi Aç", systemImage: "faceid")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onAppear {
                    authenticate()
                }
            } else {
                content
            }
        }
    }
    
    private func authenticate() {
        security.authenticate(reason: reason) { _ in }
    }
}

extension View {
    func secured(reason: String = "Erişim İzni") -> some View {
        self.modifier(SecureViewModifier(reason: reason))
    }
}
