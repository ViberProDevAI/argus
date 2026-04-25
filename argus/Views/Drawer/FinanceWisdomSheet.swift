import SwiftUI

struct FinanceWisdomSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let allCategoryLabel = "Tümü"

    @State private var allQuotes: [WisdomQuote] = []
    @State private var filteredQuotes: [WisdomQuote] = []
    @State private var availableCategories: [String] = []

    @State private var pendingSearchText = ""
    @State private var pendingCategory = "Tümü"

    @State private var activeSearchText = ""
    @State private var activeCategory = "Tümü"

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "FİNANS SÖZLERİ",
                subtitle: "DİSİPLİN · PSİKOLOJİ · USTALAR",
                leadingDeco: .bars3([.holo, .text, .text]),
                actions: [.custom(sfSymbol: "xmark", action: { dismiss() })]
            )
            VStack(spacing: 0) {
                filterBar
                quotesList
            }
            .background(InstitutionalTheme.Colors.background)
            .onAppear {
                loadQuotes()
                applyFilter()
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                TextField("Söz ara...", text: $pendingSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                Button("Bul") {
                    applyFilter()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).fill(InstitutionalTheme.Colors.holo))
            }
            .padding(12)
            .background(InstitutionalTheme.Colors.surface1)

            HStack(spacing: 10) {
                Text("Kategori")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                Picker("Kategori", selection: $pendingCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                if !activeSearchText.isEmpty || activeCategory != allCategoryLabel {
                    Button("Temizle") {
                        pendingSearchText = ""
                        pendingCategory = allCategoryLabel
                        applyFilter()
                    }
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
    }

    // MARK: - List

    private var quotesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if filteredQuotes.isEmpty {
                    Text("Sonuç bulunamadı")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .padding(.top, 20)
                } else {
                    ForEach(filteredQuotes) { quote in
                        quoteRow(quote)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func quoteRow(_ quote: WisdomQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(quote.quote)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .italic()

            HStack(spacing: 8) {
                Text("- \(quote.author)")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                Spacer()

                Text(quote.category.uppercased())
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).fill(InstitutionalTheme.Colors.holo.opacity(0.15)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).fill(InstitutionalTheme.Colors.surface1))
    }

    // MARK: - Data

    private func loadQuotes() {
        let quotes = WisdomService.shared.getAllQuotes()
        let categories = Set(quotes.map { $0.category })
        let sortedCategories = categories.sorted()
        allQuotes = quotes
        availableCategories = [allCategoryLabel] + sortedCategories
        if !availableCategories.contains(pendingCategory) {
            pendingCategory = allCategoryLabel
        }
        if !availableCategories.contains(activeCategory) {
            activeCategory = allCategoryLabel
        }
    }

    private func applyFilter() {
        activeSearchText = pendingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        activeCategory = pendingCategory
        filteredQuotes = allQuotes.filter { quote in
            let matchesCategory = (activeCategory == allCategoryLabel) || quote.category == activeCategory
            if activeSearchText.isEmpty {
                return matchesCategory
            }
            let matchesText = quote.quote.localizedCaseInsensitiveContains(activeSearchText) ||
                quote.author.localizedCaseInsensitiveContains(activeSearchText)
            return matchesCategory && matchesText
        }
    }
}

#Preview {
    FinanceWisdomSheet()
}
