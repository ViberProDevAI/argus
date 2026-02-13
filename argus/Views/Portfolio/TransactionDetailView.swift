import SwiftUI
struct TransactionDetailView: View {
    let transaction: Transaction
    let snapshot: DecisionSnapshot?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Transaction Summary
                    VStack(spacing: 8) {
                        Text(transaction.type == .buy ? "ALIŞ İŞLEMİ" : "SATIŞ İŞLEMİ")
                            .font(.headline)
                            .bold()
                            .foregroundColor(transaction.type == .buy ? Theme.positive : Theme.negative)
                        
                        Text(transaction.symbol)
                            .font(.system(size: 32, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(transaction.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // 2. Decision Rationale (The "Why")
                    // Handle MANUAL logic explicitly
                    if transaction.source == "MANUAL" {
                         VStack(alignment: .leading, spacing: 12) {
                             HStack {
                                 Image(systemName: "person.fill.checkmark")
                                     .foregroundColor(Theme.tint)
                                 Text("Manuel İşlem (Kullanıcı Kararı)")
                                     .font(.headline)
                                     .bold()
                                     .foregroundColor(.white)
                             }
                             
                             Text("Bu işlem kullanıcı tarafından manuel olarak girilmiştir. Sistem sinyallerinden bağımsızdır.")
                                 .font(.body)
                                 .foregroundColor(.gray)
                                 .padding()
                                 .background(Theme.secondaryBackground)
                                 .cornerRadius(8)
                             
                             // Optional: Show what the system THOUGHT at that time
                             if let s = snapshot {
                                  DisclosureGroup("O Sırada Argus Ne Düşünüyordu?") {
                                      AgoraDetailPanel(
                                          symbol: transaction.symbol,
                                          snapshot: s,
                                          trace: nil
                                      )
                                      .padding(.top, 8)
                                  }
                                  .foregroundColor(Theme.textSecondary)
                             }
                         }
                         .padding(.horizontal)
                    } else if let s = snapshot {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(Theme.tint)
                                Text("Karar Mekanizması (Argus/Agora)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            
                            AgoraDetailPanel(
                                symbol: transaction.symbol,
                                snapshot: s,
                                trace: nil // If we had trace we could pass it
                            )
                        }
                        .padding(.horizontal)
                    } else {
                        // Fallback
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Karar Notları")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let reason = transaction.reasonCode {
                                Text(reason)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .padding()
                                    .background(Theme.secondaryBackground)
                                    .cornerRadius(8)
                            } else {
                                Text("Bu işlem için detaylı karar kaydı bulunamadı.")
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 3. Execution Detail
                    VStack(alignment: .leading, spacing: 16) {
                        Text("İşlem Detayları")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 0) {
                            let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                            DetailRow(text: "Fiyat: \(currencySymbol)\(String(format: "%.2f", transaction.price))")
                            Divider().background(Theme.secondaryBackground)
                            
                            // Highlighted Amount
                            HStack {
                                Text("Toplam Tutar")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                                Text("\(currencySymbol)\(String(format: "%.2f", transaction.amount))")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Theme.tint)
                            }
                            .padding()
                            
                            Divider().background(Theme.secondaryBackground)
                            DetailRow(text: "Kaynak: \(transaction.source ?? "N/A")")
                            if let fee = transaction.fee {
                                Divider().background(Theme.secondaryBackground)
                                let currencySymbol = transaction.symbol.hasSuffix(".IS") ? "₺" : "$"
                                DetailRow(text: "Komisyon: \(currencySymbol)\(String(format: "%.2f", fee))")
                            }
                        }
                        .background(Theme.secondaryBackground.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("İşlem Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Console Style History Row
