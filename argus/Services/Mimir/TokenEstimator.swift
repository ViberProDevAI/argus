import Foundation

struct TokenEstimator {
    /// Rough heuristic: 1 token ~= 4 chars (English).
    /// Safe over-estimate: max(64, count/3.5)
    nonisolated static func estimate(prompt: String) -> Int {
        let count = Double(prompt.count)
        let est = count / 3.5
        return max(64, Int(est))
    }
    
    nonisolated static func estimate(inputs: [String: String]) -> Int {
        let totalChars = inputs.values.reduce(0) { $0 + $1.count }
        return estimate(prompt: String(repeating: " ", count: totalChars))
    }
}
