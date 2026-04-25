import Foundation

enum FinanceTermCategory: String, CaseIterable, Identifiable {
    case technical = "Teknik Analiz"
    case fundamental = "Temel Analiz"
    case market = "Piyasa Terimleri"
    case macro = "Makro Ekonomi"
    case trading = "Borsa İşlemleri"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .technical: return "chart.xyaxis.line"
        case .fundamental: return "doc.text.magnifyingglass"
        case .market: return "building.columns"
        case .macro: return "globe"
        case .trading: return "arrow.left.arrow.right"
        }
    }
}
