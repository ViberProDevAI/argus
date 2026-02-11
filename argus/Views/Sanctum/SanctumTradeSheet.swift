import SwiftUI

struct SanctumTradeSheet: View {
    let symbol: String
    let viewModel: TradingViewModel
    let action: ArgusSanctumView.TradeAction

    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var execution = ExecutionStateViewModel.shared
    @State private var quantity: Double = 0
    @State private var price: Double = 0
    @State private var quantityString = ""
    @State private var priceString = ""
    @State private var tradeSuccess = false
    @State private var showError = false

    private var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }

    private var availableBalance: Double {
        isBist ? PortfolioStore.shared.bistBalance : PortfolioStore.shared.globalBalance
    }

    private var balanceLabel: String {
        isBist ? "₺" : "$"
    }

    private var estimatedCost: Double {
        quantity * price * 1.002
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ISLEM DETAYLARI")) {
                    HStack {
                        Text("Sembol")
                        Spacer()
                        Text(symbol).bold()
                    }

                    HStack {
                        Text("Islem")
                        Spacer()
                        Text(action == .buy ? "ALIS" : "SATIS")
                            .foregroundColor(action == .buy ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                            .bold()
                    }

                    HStack {
                        Text("Mevcut Fiyat")
                        Spacer()
                        if let quote = viewModel.quotes[symbol] {
                            Text(String(format: "%.2f", quote.currentPrice))
                        } else {
                            Text("Veri yok")
                                .foregroundColor(SanctumTheme.crimsonRed)
                        }
                    }

                    // Bakiye bilgisi
                    HStack {
                        Text("Bakiye")
                        Spacer()
                        Text("\(balanceLabel)\(String(format: "%.2f", max(0, availableBalance)))")
                            .foregroundColor(availableBalance > 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
                    }

                    TextField("Adet Giriniz", text: $quantityString)
                        .keyboardType(.decimalPad)
                        .onChange(of: quantityString) { newValue in
                            if let val = Double(newValue) { quantity = val }
                        }

                    TextField("Fiyat (Opsiyonel)", text: $priceString)
                        .keyboardType(.decimalPad)
                        .onChange(of: priceString) { newValue in
                            if let val = Double(newValue) { price = val }
                        }

                    // Tahmini maliyet
                    if quantity > 0 && price > 0 {
                        HStack {
                            Text("Tahmini Maliyet")
                            Spacer()
                            Text("\(balanceLabel)\(String(format: "%.2f", estimatedCost))")
                                .foregroundColor(estimatedCost > availableBalance ? SanctumTheme.crimsonRed : InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                }

                // Hata mesaji
                if let error = execution.lastTradeError, showError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(SanctumTheme.crimsonRed)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(SanctumTheme.crimsonRed)
                        }
                    }
                }

                // Basari mesaji
                if tradeSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(SanctumTheme.auroraGreen)
                            Text("Islem basarili!")
                                .foregroundColor(SanctumTheme.auroraGreen)
                                .bold()
                        }
                    }
                }

                Section {
                    Button(action: executeTrade) {
                        HStack {
                            Spacer()
                            Text(action == .buy ? "EMRI GONDER (AL)" : "EMRI GONDER (SAT)")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(quantity <= 0 || tradeSuccess)
                    .listRowBackground((action == .buy ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed).opacity(quantity > 0 && !tradeSuccess ? 0.25 : 0.12))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SanctumTheme.bg)
            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            .tint(SanctumTheme.hologramBlue)
            .navigationTitle(action == .buy ? "Argus Alis" : "Argus Satis")
            .navigationBarItems(trailing: Button("Iptal") { presentationMode.wrappedValue.dismiss() })
        }
        .onAppear {
            if let quote = viewModel.quotes[symbol] {
                price = quote.currentPrice
                priceString = String(format: "%.2f", price)
            }
            execution.lastTradeError = nil
        }
    }

    private func executeTrade() {
        guard quantity > 0 else { return }
        showError = false
        tradeSuccess = false
        execution.lastTradeError = nil

        if action == .buy {
            viewModel.executeBuy(symbol: symbol, quantity: quantity, price: price)
        } else {
            viewModel.executeSell(symbol: symbol, quantity: quantity, price: price)
        }

        // executeBuy/Sell is async via Task — check result after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let error = execution.lastTradeError {
                showError = true
                print("❌ SanctumTradeSheet: \(error)")
            } else {
                tradeSuccess = true
                // Auto-dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
