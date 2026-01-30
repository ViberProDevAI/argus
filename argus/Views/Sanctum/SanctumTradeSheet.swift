import SwiftUI

struct SanctumTradeSheet: View {
    let symbol: String
    let viewModel: TradingViewModel
    let action: ArgusSanctumView.TradeAction
    
    @Environment(\.presentationMode) var presentationMode
    @State private var quantity: Double = 0
    @State private var price: Double = 0
    @State private var quantityString = ""
    @State private var priceString = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("İŞLEM DETAYLARI")) {
                    HStack {
                        Text("Sembol")
                        Spacer()
                        Text(symbol).bold()
                    }
                    
                    HStack {
                        Text("İşlem")
                        Spacer()
                        Text(action == .buy ? "ALIŞ" : "SATIŞ")
                            .foregroundColor(action == .buy ? .green : .red)
                            .bold()
                    }
                    
                    HStack {
                        Text("Mevcut Fiyat")
                        Spacer()
                        if let quote = viewModel.quotes[symbol] {
                            Text(String(format: "%.2f", quote.currentPrice))
                        }
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
                }
                
                Section {
                    Button(action: executeTrade) {
                        HStack {
                            Spacer()
                            Text(action == .buy ? "EMRİ GÖNDER (AL)" : "EMRİ GÖNDER (SAT)")
                                .bold()
                            Spacer()
                        }
                    }
                    .listRowBackground(action == .buy ? Color.green : Color.red)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle(action == .buy ? "Argus Alış" : "Argus Satış")
            .navigationBarItems(trailing: Button("İptal") { presentationMode.wrappedValue.dismiss() })
        }
        .onAppear {
            if let quote = viewModel.quotes[symbol] {
                price = quote.currentPrice
                priceString = String(format: "%.2f", price)
            }
        }
    }
    
    private func executeTrade() {
        guard quantity > 0 else { return }
        
        // Use ViewModel's trade function
        if action == .buy {
            viewModel.executeBuy(symbol: symbol, quantity: quantity, price: price)
        } else {
            viewModel.executeSell(symbol: symbol, quantity: quantity, price: price)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}
