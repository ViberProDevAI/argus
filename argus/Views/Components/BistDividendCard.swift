import SwiftUI

// MARK: - BIST Temettü Kartı
// BorsaPy üzerinden İş Yatırım'dan temettü verilerini gösterir

struct BistDividendCard: View {
    let symbol: String
    @State private var dividends: [BistDividend] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "banknote.fill")
                        .foregroundColor(.orange)
                    Text("Temettü Geçmişi")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if dividends.isEmpty && !isLoading {
                    Text("Bu hisse için temettü kaydı bulunamadı.")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    // Temettü listesi
                    ForEach(dividends.prefix(5)) { dividend in
                        DividendRow(dividend: dividend)
                    }
                    
                    // Toplam temettü verimi göstergesi
                    if let lastDividend = dividends.first {
                        Divider().background(Color.gray.opacity(0.3))
                        
                        HStack {
                            Text("Son Temettü")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("%\(String(format: "%.1f", lastDividend.grossRate)) Brüt")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear {
                loadDividends()
            }
        }
    }
    
    private func loadDividends() {
        Task {
            do {
                let result = try await BorsaPyProvider.shared.getDividends(symbol: symbol)
                await MainActor.run {
                    self.dividends = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Veri yüklenemedi"
                    self.isLoading = false
                }
            }
        }
    }
}

struct DividendRow: View {
    let dividend: BistDividend
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(dividend.date))
                    .font(.caption)
                    .foregroundColor(.white)
                Text("Hisse başı: ₺\(String(format: "%.2f", dividend.perShare))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("%\(String(format: "%.1f", dividend.grossRate))")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.orange)
                Text("Brüt")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - BIST Sermaye Artırımı Kartı
struct BistCapitalIncreaseCard: View {
    let symbol: String
    @State private var capitalIncreases: [BistCapitalIncrease] = []
    @State private var isLoading = true
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist && !capitalIncreases.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundColor(.purple)
                    Text("Sermaye Artırımları")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                ForEach(capitalIncreases.prefix(3)) { increase in
                    CapitalIncreaseRow(increase: increase)
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear {
                loadCapitalIncreases()
            }
        }
    }
    
    private func loadCapitalIncreases() {
        Task {
            do {
                let result = try await BorsaPyProvider.shared.getCapitalIncreases(symbol: symbol)
                await MainActor.run {
                    self.capitalIncreases = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct CapitalIncreaseRow: View {
    let increase: BistCapitalIncrease
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(increase.date))
                    .font(.caption)
                    .foregroundColor(.white)
                
                if increase.rightsIssueRate > 0 {
                    Text("Bedelli: %\(String(format: "%.0f", increase.rightsIssueRate))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            if increase.totalBonusRate > 0 {
                Text("Bedelsiz %\(String(format: "%.0f", increase.totalBonusRate))")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        BistDividendCard(symbol: "THYAO.IS")
        BistCapitalIncreaseCard(symbol: "THYAO.IS")
    }
    .padding()
    .background(Theme.background)
}
