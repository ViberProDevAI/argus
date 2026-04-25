import SwiftUI

/// V5 API Key merkezi — `APIKeyCenterView`'u ArgusNavHeader ile sarar.
struct HeimdallKeysView: View {
    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "API KEY MERKEZİ",
                subtitle: "HEIMDALL · ANAHTAR YÖNETİMİ",
                leadingDeco: .bars3([.holo, .text, .text])
            )
            APIKeyCenterView()
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
