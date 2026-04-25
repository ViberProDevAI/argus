import Foundation

struct WisdomQuote: Codable, Identifiable {
    var id: String { "\(author)-\(quote.prefix(20))" }
    let quote: String
    let author: String
    let category: String
}

enum WisdomCategory: String, CaseIterable {
    case risk = "risk"
    case patience = "patience"
    case strategy = "strategy"
    case psychology = "psychology"
    case growth = "growth"
}
