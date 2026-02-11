import SwiftUI

struct SystemHealthSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ServiceHealthView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                            .foregroundColor(Theme.tint)
                    }
                }
        }
    }
}
