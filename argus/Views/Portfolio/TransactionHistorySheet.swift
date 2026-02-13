import SwiftUI
struct TransactionHistorySheet: View {
    @ObservedObject var viewModel: TradingViewModel
    var marketMode: TradeMarket // Global or BIST
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTxn: Transaction? // State for tapping
    
    // Filtered Transactions
    var filteredTransactions: [Transaction] {
        viewModel.transactionHistory.filter { txn in
            if marketMode == .bist {
                return txn.currency == .TRY
            } else {
                return txn.currency == .USD
            }
        }.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if filteredTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "terminal")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary.opacity(0.3))
                        Text(marketMode == .bist ? "BIST Geçmişi Boş" : "Global Geçmiş Boş")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(filteredTransactions) { txn in
                            Button(action: {
                                selectedTxn = txn
                            }) {
                                TransactionConsoleCard(txn: txn)
                            }
                            .listRowInsets(EdgeInsets()) // Full width look
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("İşlem Konsolu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Theme.tint)
                }
            }
            .sheet(item: $selectedTxn) { txn in
                // Look up full snapshot if available
                let snapshot = viewModel.agoraSnapshots.first(where: { $0.id.uuidString == txn.decisionId })
                TransactionDetailView(transaction: txn, snapshot: snapshot)
            }
        }
    }
}

// MARK: - Transaction Detail View
