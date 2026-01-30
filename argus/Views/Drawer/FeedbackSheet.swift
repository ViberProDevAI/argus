import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType = 0
    @State private var feedbackText = ""
    @State private var showingConfirmation = false

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
                Text("Gönder")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(Theme.background)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(feedbackText.isEmpty ? Theme.tint.opacity(0.3) : Theme.tint)
            )
        }
        .disabled(feedbackText.isEmpty)
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("İLETİŞİM")

            Text("Acil sorunlar için: destek@argus.app")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Text("Geri bildirimler genellikle 24-48 saat içinde değerlendirilir.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Actions

    private func submitFeedback() {
        // Burada gercek bir API cagrisi yapilabilir
        // Simdilik sadece confirmation goster
        showingConfirmation = true
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
