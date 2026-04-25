import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType = 0
    @State private var feedbackText = ""
    @State private var showingConfirmation = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let feedbackTypes = ["Hata Bildirimi", "Öneri", "Soru", "Diğer"]

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "GERİ BİLDİRİM",
                subtitle: "ARGUS · KANAL · KULLANICI",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [.custom(sfSymbol: "xmark", action: { dismiss() })]
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    typeSection
                    messageSection
                    submitSection
                    contactSection
                }
                .padding(20)
            }
            .background(InstitutionalTheme.Colors.background)
            .alert("Gönderildi", isPresented: $showingConfirmation) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Geri bildiriminiz alındı. Teşekkürler.")
            }
            .alert("Gönderim Hatası", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("Tamam") { }
            } message: {
                Text(errorMessage ?? "Beklenmeyen bir hata oluştu.")
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Type Selection

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BİLDİRİM TÜRÜ")

            Picker("Tür", selection: $feedbackType) {
                ForEach(0..<feedbackTypes.count, id: \.self) { index in
                    Text(feedbackTypes[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Message

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MESAJINIZ")

            ZStack(alignment: .topLeading) {
                if feedbackText.isEmpty {
                    Text("Geri bildiriminizi buraya yazın...")
                        .font(.subheadline)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $feedbackText)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .accessibilityLabel("Geri bildirim mesajı")
                    .accessibilityHint("Bildirmek istediğiniz konuyu buraya yazın, maksimum 1000 karakter")
            }
            .frame(minHeight: 150)
            .background(Color.white.opacity(0.03))
            .cornerRadius(InstitutionalTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md)
                    .stroke(InstitutionalTheme.Colors.holo.opacity(0.2), lineWidth: 1)
            )

            Text("\(feedbackText.count) / 1000 karakter")
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .accessibilityLabel("\(feedbackText.count) karakter, en fazla 1000")
        }
    }

    // MARK: - Submit

    private var submitSection: some View {
        Button {
            submitFeedback()
        } label: {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .tint(InstitutionalTheme.Colors.background)
                } else {
                    Text("Gönder")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .foregroundColor(InstitutionalTheme.Colors.background)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md)
                    .fill(feedbackText.isEmpty || isSubmitting ? InstitutionalTheme.Colors.holo.opacity(0.3) : InstitutionalTheme.Colors.holo)
            )
        }
        .disabled(feedbackText.isEmpty || isSubmitting)
        .accessibilityLabel(isSubmitting ? "Gönderiliyor" : "Geri bildirimi gönder")
        .accessibilityHint(feedbackText.isEmpty ? "Önce bir mesaj yazın" : "Geri bildiriminiz Argus ekibine iletilecek")
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("İLETİŞİM")

            Button {
                openInstagramDM()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.15, blue: 0.45), Color(red: 0.95, green: 0.45, blue: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Instagram'dan DM at")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text("@sigarayib1rak")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(InstitutionalTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }

            Text("Geri bildirimler genellikle 24-48 saat içinde değerlendirilir.")
                .font(.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    // MARK: - Actions

    private func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true
        errorMessage = nil

        let type = feedbackTypes[feedbackType]
        let message = feedbackText

        Task {
            do {
                try await FeedbackService.shared.submit(type: type, message: message)
                await MainActor.run {
                    isSubmitting = false
                    showingConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func openInstagramDM() {
        let appURL = URL(string: "instagram://user?username=sigarayib1rak")!
        let webURL = URL(string: "https://ig.me/m/sigarayib1rak")!
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .tracking(0.5)
    }
}

#Preview {
    FeedbackSheet()
}
