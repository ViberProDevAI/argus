import SwiftUI

struct SystemHealthSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ServiceHealthView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                            .foregroundColor(InstitutionalTheme.Colors.holo)
                    }
                }
        }
    }
}
