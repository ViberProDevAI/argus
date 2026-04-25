import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    /// Güvenli subscript - index geçersizse nil döner (crash önler)
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    /// Güvenli first - boş array'de nil döner
    var safeFirst: Element? { first }

    /// Güvenli last - boş array'de nil döner
    var safeLast: Element? { last }

    /// Güvenli son N eleman
    func safeSuffix(_ n: Int) -> [Element] {
        guard n > 0 else { return [] }
        return Array(suffix(Swift.min(n, count)))
    }

    /// Güvenli ilk N eleman
    func safePrefix(_ n: Int) -> [Element] {
        guard n > 0 else { return [] }
        return Array(prefix(Swift.min(n, count)))
    }
}
