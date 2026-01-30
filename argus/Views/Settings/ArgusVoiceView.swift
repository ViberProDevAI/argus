import SwiftUI

struct ArgusVoiceView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var tradingVM: TradingViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isListening = false
    @State private var showSuggestions = true
    
    // Design 14: Suggestions
    let suggestions = [
        "Portföy durumum ne?",
        "AAPL için analiz yap",
        "Bugün ne almalıyım?",
        "Piyasa neden düşüyor?"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.tint)
                        Text("Argus Voice")
                            .font(.headline)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(Theme.textSecondary)
                                .padding(8)
                                .background(Theme.secondaryBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(Theme.background.opacity(0.95))
                    
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome Message
                                if viewModel.messages.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(Theme.tint)
                                            .padding()
                                            .background(Theme.tint.opacity(0.1))
                                            .clipShape(Circle())
                                        
                                        Text("Merhaba, ben Argus.")
                                            .font(.title3)
                                            .bold()
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text("Piyasalar, portföyün veya hisseler hakkında bana soru sorabilirsin.")
                                            .font(.body)
                                            .foregroundColor(Theme.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                    }
                                    .padding(.top, 60)
                                    .transition(.opacity)
                                }
                                
                                ForEach(viewModel.messages) { msg in
                                    ChatMessageBubble(message: msg)
                                        .id(msg.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack(spacing: 4) {
                                        Circle().fill(Theme.tint).frame(width: 8, height: 8)
                                        Circle().fill(Theme.tint).frame(width: 8, height: 8)
                                        Circle().fill(Theme.tint).frame(width: 8, height: 8)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 56) // Align with bubble
                                    .padding(.vertical, 8)
                                }
                                
                                Spacer().frame(height: 20)
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) {
                            if let last = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Suggestions (if empty or just started)
                    if viewModel.messages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(suggestions, id: \.self) { text in
                                    Button(action: {
                                        viewModel.inputMessage = text
                                        showSuggestions = false
                                        viewModel.sendMessage()
                                    }) {
                                        Text(text)
                                            .font(.footnote)
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Theme.cardBackground)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Theme.secondaryBackground, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Input Bar
                    VStack(spacing: 0) {
                        Divider().background(Theme.secondaryBackground)
                        
                        HStack(alignment: .bottom, spacing: 12) {
                            // Text Input
                            TextField("Bir şeyler yaz...", text: $viewModel.inputMessage, axis: .vertical)
                                .lineLimit(1...5)
                                .padding(12)
                                .background(Theme.cardBackground)
                                .cornerRadius(24)
                                .foregroundColor(Theme.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Theme.secondaryBackground, lineWidth: 1)
                                )
                            
                            // Send Button or Mic
                            if viewModel.inputMessage.isEmpty {
                                SpeechButton()
                            } else {
                                Button(action: {
                                    viewModel.sendMessage()
                                }) {
                                    Image(systemName: "arrow.up")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(Theme.tint)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()
                        .background(Theme.background)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                let decisions = Array(tradingVM.argusDecisions.values)
                viewModel.updateContext(decisions: decisions, portfolio: tradingVM.portfolio)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpeechFinished"))) { notification in
                if let text = notification.object as? String {
                    viewModel.inputMessage = text
                    // Optional: Auto-send if silence detection is good
                    // viewModel.sendMessage() 
                }
            }
        }
    }
}

// MARK: - Subviews

struct SpeechButton: View {
    @StateObject private var speechService = ArgusSpeechService.shared
    @EnvironmentObject var viewModel: ChatViewModel // Needs to be injected or accessed
    // Wait, ChatViewModel is StateObject in parent. We need to pass it or accessible.
    // Changing approach slightly to keep logic in parent or use binding.
    // But for cleaner code, let's keep SpeechService logic here.
    
    var body: some View {
        Button(action: { toggleRecording() }) {
            ZStack {
                if speechService.isRecording {
                    // Pulsing Waveform (Fake Visualization based on level)
                    Circle()
                        .stroke(Theme.negative.opacity(0.5), lineWidth: 4)
                        .frame(width: 54 + CGFloat(speechService.audioLevel * 40), height: 54 + CGFloat(speechService.audioLevel * 40))
                        .animation(.linear(duration: 0.1), value: speechService.audioLevel)
                    
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 48, height: 48)
            .background(speechService.isRecording ? Theme.negative : Theme.tint)
            .clipShape(Circle())
        }
        .onChange(of: speechService.recognizedText) {
             // Live Transcription Update (Optional: could verify if we want live update in textfield)
             // Let's assume we want to fill the Parent's viewModel.inputMessage
             // This requires binding.
        }
    }
    
    func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
            // Send the text
            // Need a way to convert partial text to inputMessage
             NotificationCenter.default.post(name: NSNotification.Name("SpeechFinished"), object: speechService.recognizedText)
        } else {
            try? speechService.startRecording()
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !isUser {
                // Bot Avatar
                ZStack {
                    Circle()
                        .fill(Theme.cardBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(Theme.tint)
                        .font(.title3)
                }
            } else {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(isUser ? .white.opacity(0.8) : Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .padding(.horizontal, 4)
            .background(isUser ? Theme.tint : Theme.cardBackground)
            .cornerRadius(20, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            
            if isUser {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(Theme.secondaryBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.body)
                }
            } else {
                Spacer()
            }
        }
    }
}


