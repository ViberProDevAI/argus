import Foundation
import Combine

final class FinanceTermsRepository: ObservableObject {
    static let shared = FinanceTermsRepository()

    @Published private(set) var filteredTerms: [FinanceTerm] = []
    @Published var searchQuery: String = "" {
        didSet { updateFilteredTerms() }
    }
    @Published var selectedCategory: FinanceTermCategory? = nil {
        didSet { updateFilteredTerms() }
    }

    private lazy var allTerms: [FinanceTerm] = {
        let terms = Self.technicalTerms
            + Self.fundamentalTerms
            + Self.marketTerms
            + Self.macroTerms
            + Self.tradingTerms
        return terms.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }()

    private init() {
        filteredTerms = allTerms
    }

    // MARK: - Public Methods

    func search(_ query: String) -> [FinanceTerm] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return allTerms
        }
        let lowercased = query.lowercased()
        return allTerms.filter {
            $0.term.lowercased().contains(lowercased) ||
            ($0.fullName?.lowercased().contains(lowercased) ?? false) ||
            $0.definition.lowercased().contains(lowercased)
        }
    }

    func terms(for category: FinanceTermCategory) -> [FinanceTerm] {
        allTerms.filter { $0.category == category }
    }

    func term(byId id: String) -> FinanceTerm? {
        allTerms.first { $0.id == id }
    }

    func relatedTerms(for term: FinanceTerm) -> [FinanceTerm] {
        term.relatedTerms.compactMap { relatedName in
            allTerms.first { $0.term.lowercased() == relatedName.lowercased() }
        }
    }

    var totalCount: Int {
        allTerms.count
    }

    func count(for category: FinanceTermCategory) -> Int {
        allTerms.filter { $0.category == category }.count
    }

    // MARK: - Private Methods

    private func updateFilteredTerms() {
        var results = allTerms

        // Kategori filtresi
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        // Arama filtresi
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let lowercased = searchQuery.lowercased()
            results = results.filter {
                $0.term.lowercased().contains(lowercased) ||
                ($0.fullName?.lowercased().contains(lowercased) ?? false) ||
                $0.definition.lowercased().contains(lowercased)
            }
        }

        filteredTerms = results
    }

    func resetFilters() {
        searchQuery = ""
        selectedCategory = nil
    }
}
