import SwiftUI

struct SignalJournalView: View {
    // Legacy Service Removed
    // @ObservedObject var tracker = SignalTrackerService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Sinyal Günlüğü Taşındı")
                .font(.title2)
                .bold()
            
            Text("Argus 3.0 ile birlikte Sinyal Günlüğü, 'Argus Ledger' altyapısına taşınmıştır. Eski manuel günlük sistemi devre dışı bırakılmıştır.")
                .multilineTextAlignment(.center)
                .padding()
                .foregroundColor(.secondary)
            
            Text("Verileriniz güvende: Tüm sinyaller artık otomatik olarak Argus Veritabanına (SQLite) kaydedilmektedir.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .navigationTitle("Sinyal Karnesi")
    }
}
