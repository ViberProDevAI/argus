import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let service = ArgusExplanationService.shared
    
    // Context Store
    var contextDecisions: [ArgusDecisionResult] = []
    var contextPortfolio: [Trade] = []
    
    init() {
        // Initial Greeting
        messages.append(ChatMessage(id: UUID(), role: .assistant, content: "Merhaba Kaptan! Ben Argus. Piyasalar, portföyün veya stratejilerin hakkında ne bilmek istersin?", timestamp: Date()))
    }
    
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = ChatMessage(id: UUID(), role: .user, content: inputMessage, timestamp: Date())
        messages.append(userMsg)
        
        inputMessage = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let responseText = try await service.chat(
                    history: messages,
                    contextDecisions: contextDecisions,
                    portfolio: contextPortfolio
                )
                let aiMsg = ChatMessage(id: UUID(), role: .assistant, content: responseText, timestamp: Date())
                messages.append(aiMsg)
                isLoading = false
            } catch {
                print("❌ Chat Error: \(error)")
                let errorText = "Hata: \(error.localizedDescription)"
                let errorMsg = ChatMessage(id: UUID(), role: .assistant, content: errorText, timestamp: Date())
                messages.append(errorMsg)
                isLoading = false
            }
        }
    }
    
    func updateContext(decisions: [ArgusDecisionResult], portfolio: [Trade]) {
        self.contextDecisions = decisions
        self.contextPortfolio = portfolio
    }
}
