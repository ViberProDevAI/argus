import Foundation

struct FinanceTerm: Identifiable, Equatable {
    let id: String
    let term: String
    let fullName: String?
    let definition: String
    let formula: String?
    let argusUsage: String?
    let relatedTerms: [String]
    let category: FinanceTermCategory

    init(
        id: String,
        term: String,
        fullName: String? = nil,
        definition: String,
        formula: String? = nil,
        argusUsage: String? = nil,
        relatedTerms: [String] = [],
        category: FinanceTermCategory
    ) {
        self.id = id
        self.term = term
        self.fullName = fullName
        self.definition = definition
        self.formula = formula
        self.argusUsage = argusUsage
        self.relatedTerms = relatedTerms
        self.category = category
    }
}
