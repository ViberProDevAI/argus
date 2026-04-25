import SwiftUI

// MARK: - SanctumDecisionPanel
//
// Argus Sanctum ana ekranında konsey kararı gösterimi için ince sarmalayıcı.
// Görünürlük mantığı (karar mevcut + modül seçili değil) tek yerde toplanır ve
// ArgusSanctumView body'si sadeleştirilir.
//
// Gerçek görsel (skor rozeti, katkı çubukları, CTA'lar) önceden yazılmış olan
// `SanctumContributionCard` içinde kalır; burada kompozisyon yapılır.
//
// Kullanım:
//     SanctumDecisionPanel(
//         decision: activeDecision,
//         isBist: isBistSymbol,
//         isVisible: showDecision && selectedModule == nil && selectedBistModule == nil
//     )
//
// Demo veri yok — `decision` nil ise ya da `isVisible == false` ise panel
// hiç render edilmez.

struct SanctumDecisionPanel: View {
    let decision: ArgusGrandDecision?
    let isBist: Bool
    let isVisible: Bool

    var body: some View {
        if isVisible, let decision {
            SanctumContributionCard(
                decision: decision,
                isBist: isBist
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
