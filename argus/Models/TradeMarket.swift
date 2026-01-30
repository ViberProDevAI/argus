import Foundation

/// İşlem yapılan pazar türü (BIST veya Global)
/// UI ve mantık katmanlarında ortak kullanılır.
enum TradeMarket: String, CaseIterable, Sendable {
    case global = "Global"
    case bist = "BIST"
}
