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
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // V5 Header — Argus göz radial gradient + Argus Voice başlık
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color(hex: "6AA5FF"), location: 0),
                                            .init(color: InstitutionalTheme.Colors.holo, location: 0.55),
                                            .init(color: Color(hex: "143A7A"), location: 1.0)
                                        ]),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 0,
                                        endRadius: 24
                                    )
                                )
                                .frame(width: 40, height: 40)
                            MotorLogo(.argus, size: 28)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Argus Voice")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Text("SESLİ ASİSTAN · ONLINE")
                                .font(InstitutionalTheme.Typography.dataMicro)
                                .tracking(1.2)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        }

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(InstitutionalTheme.Colors.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        InstitutionalTheme.Colors.background
                            .overlay(ArgusHair().frame(maxHeight: .infinity, alignment: .bottom))
                    )
                    
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome Message
                                if viewModel.messages.isEmpty {
                                    // V5 welcome: büyük Argus göz + karşılama
                                    VStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        gradient: Gradient(stops: [
                                                            .init(color: Color(hex: "6AA5FF"), location: 0),
                                                            .init(color: InstitutionalTheme.Colors.holo, location: 0.55),
                                                            .init(color: Color(hex: "143A7A"), location: 1.0)
                                                        ]),
                                                        center: UnitPoint(x: 0.3, y: 0.3),
                                                        startRadius: 0,
                                                        endRadius: 48
                                                    )
                                                )
                                                .frame(width: 80, height: 80)
                                                .shadow(color: InstitutionalTheme.Colors.holo.opacity(0.4),
                                                        radius: 20)
                                            Circle()
                                                .stroke(InstitutionalTheme.Colors.holo.opacity(0.25), lineWidth: 1)
                                                .frame(width: 96, height: 96)
                                            MotorLogo(.argus, size: 60)
                                        }

                                        Text("Merhaba, ben Argus.")
                                            .font(.system(size: 22, weight: .black))
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                                        Text("Piyasalar, portföyün veya hisseler hakkında bana soru sorabilirsin.")
                                            .font(InstitutionalTheme.Typography.caption)
                                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                    }
                                    .padding(.top, 40)
                                    .transition(.opacity)
                                }
                                
                                ForEach(viewModel.messages) { msg in
                                    ChatMessageBubble(message: msg)
                                        .id(msg.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack(spacing: 4) {
                                        Circle().fill(InstitutionalTheme.Colors.holo).frame(width: 8, height: 8)
                                        Circle().fill(InstitutionalTheme.Colors.holo).frame(width: 8, height: 8)
                                        Circle().fill(InstitutionalTheme.Colors.holo).frame(width: 8, height: 8)
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
                    
                    // V5 ÖNERİLER — boş state'te 4 büyük kart (motor ikonlu)
                    if viewModel.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ArgusSectionCaption("ÖNERİLER")
                                .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                v5SuggestionCard(motor: .chiron, tone: .motor(.chiron),
                                                 text: "Portföy durumum ne?")
                                v5SuggestionCard(motor: .orion, tone: .holo,
                                                 text: "AAPL için analiz yap")
                                v5SuggestionCard(motor: .prometheus, tone: .aurora,
                                                 text: "Bugün ne almalıyım?")
                                v5SuggestionCard(motor: .aether, tone: .crimson,
                                                 text: "Piyasa neden düşüyor?")
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                    }

                    // V5 input bar — pill shape + mic + send
                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(InstitutionalTheme.Colors.surface3)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        TextField("Argus'a sor...", text: $viewModel.inputMessage, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)

                        Button {
                            if !viewModel.inputMessage.isEmpty {
                                viewModel.sendMessage()
                            }
                        } label: {
                            Image(systemName: viewModel.inputMessage.isEmpty ? "waveform" : "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(InstitutionalTheme.Colors.holo)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(InstitutionalTheme.Colors.surface2)
                            .overlay(
                                Capsule().stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
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
    @ObservedObject private var speechService = ArgusSpeechService.shared
    @Binding var inputMessage: String

    var body: some View {
        Button(action: { toggleRecording() }) {
            ZStack {
                if speechService.isRecording {
                    // Pulsing Waveform (Fake Visualization based on level)
                    Circle()
                        .stroke(InstitutionalTheme.Colors.crimson.opacity(0.5), lineWidth: 4)
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
            .background(speechService.isRecording ? InstitutionalTheme.Colors.crimson : InstitutionalTheme.Colors.holo)
            .clipShape(Circle())
        }
        .onChange(of: speechService.recognizedText) { _, newText in
            // Live transcription update
            inputMessage = newText
        }
    }

    func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            try? speechService.startRecording()
        }
    }
}

// MARK: - V5 Suggestion Card

private extension ArgusVoiceView {
    func v5SuggestionCard(motor: MotorEngine, tone: ArgusChipTone, text: String) -> some View {
        Button {
            viewModel.inputMessage = text
            viewModel.sendMessage()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tone.foreground.opacity(0.15))
                        .frame(width: 28, height: 28)
                    MotorLogo(motor, size: 16)
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !isUser {
                // V5 Bot Avatar — Argus göz mini
                ZStack {
                    Circle()
                        .fill(InstitutionalTheme.Colors.holo.opacity(0.15))
                        .frame(width: 28, height: 28)
                    MotorLogo(.argus, size: 18)
                }
            } else {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : InstitutionalTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(isUser ? .white.opacity(0.8) : InstitutionalTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .padding(.horizontal, 4)
            .background(isUser ? InstitutionalTheme.Colors.holo : InstitutionalTheme.Colors.surface1)
            .cornerRadius(20, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            
            if isUser {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(InstitutionalTheme.Colors.surface1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .font(.body)
                }
            } else {
                Spacer()
            }
        }
    }
}


