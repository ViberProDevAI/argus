import SwiftUI

struct FinanceWisdomSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let allCategoryLabel = "Tumu"

    @State private var allQuotes: [WisdomQuote] = []
    @State private var filteredQuotes: [WisdomQuote] = []
    @State private var availableCategories: [String] = []

    @State private var pendingSearchText = ""
    @State private var pendingCategory = "Tumu"

    @State private var activeSearchText = ""
    @State private var activeCategory = "Tumu"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                quotesList
            }
            .background(Theme.background)
            .navigationTitle("Unlu Finans Sozleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
            .onAppear {
                loadQuotes()
                applyFilter()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)

                TextField("Soz ara...", text: $pendingSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                Button("Bul") {
                    applyFilter()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.tint))
            }
            .padding(12)
            .background(Theme.cardBackground)

            HStack(spacing: 10) {
                Text("Kategori")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

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
                    .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Theme.cardBackground.opacity(0.6))
    }

    // MARK: - List

    private var quotesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if filteredQuotes.isEmpty {
                    Text("Sonuc bulunamadi")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
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
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text(quote.category.uppercased())
                    .font(.caption2)
                    .foregroundColor(Theme.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.tint.opacity(0.15)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.cardBackground))
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
