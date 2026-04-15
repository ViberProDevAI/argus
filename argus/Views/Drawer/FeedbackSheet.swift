import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType = 0
    @State private var feedbackText = ""
    @State private var showingConfirmation = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let feedbackTypes = ["Hata Bildirimi", "Oneri", "Soru", "Diger"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    typeSection
                    messageSection
                    submitSection
                    contactSection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Geri Bildirim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
            .alert("Gönderildi", isPresented: $showingConfirmation) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Geri bildiriminiz alındı. Teşekkürler.")
            }
            .alert("Gonderim Hatasi", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("Tamam") { }
            } message: {
                Text(errorMessage ?? "Beklenmeyen bir hata olustu.")
            }
        }
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
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $feedbackText)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .frame(minHeight: 150)
            .background(Color.white.opacity(0.03))
            .cornerRadius(Theme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
            )

            Text("\(feedbackText.count) / 1000 karakter")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
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
                        .tint(Theme.background)
                } else {
                    Text("Gönder")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .foregroundColor(Theme.background)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(feedbackText.isEmpty || isSubmitting ? Theme.tint.opacity(0.3) : Theme.tint)
            )
        }
        .disabled(feedbackText.isEmpty || isSubmitting)
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
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(Theme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }

            Text("Geri bildirimler genellikle 24-48 saat içinde değerlendirilir.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
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
            .foregroundColor(Theme.textSecondary)
            .tracking(0.5)
    }
}

#Preview {
    FeedbackSheet()
}
