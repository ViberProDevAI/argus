import Foundation
import SwiftUI
import Combine

// MARK: - Scout Story Model
/// Represents a single scouting discovery for Stories UI
struct ScoutStory: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let price: Double
    let changePercent: Double
    let orionScore: Double
    let signal: ScoutSignal
    let highlights: [ScoutHighlight]
    let scannedAt: Date
    var isViewed: Bool
    
    // Computed
    var isNew: Bool {
        !isViewed && scannedAt.timeIntervalSinceNow > -3600 // Within 1 hour
    }
    
    var timeAgo: String {
        let seconds = -scannedAt.timeIntervalSinceNow
        if seconds < 60 { return "Şimdi" }
        if seconds < 3600 { return "\(Int(seconds / 60)) dk önce" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) saat önce" }
        return "\(Int(seconds / 86400)) gün önce"
    }
    
    // Signal color
    var signalColor: Color {
        switch signal {
        case .strongBuy: return .green
        case .buy: return .green.opacity(0.8)
        case .hold: return .orange
        case .sell: return .red.opacity(0.8)
        case .strongSell: return .red
        }
    }
}

// MARK: - Scout Signal
enum ScoutSignal: String, Codable, CaseIterable {
    case strongBuy = "Güçlü AL"
    case buy = "AL"
    case hold = "BEKLE"
    case sell = "SAT"
    case strongSell = "Güçlü SAT"
    
    static func from(score: Double) -> ScoutSignal {
        switch score {
        case 75...: return .strongBuy
        case 65..<75: return .buy
        case 45..<65: return .hold
        case 35..<45: return .sell
        default: return .strongSell
        }
    }
}

// MARK: - Scout Highlight
struct ScoutHighlight: Codable, Identifiable {
    var id: String { type.rawValue }
    let type: HighlightType
    let value: String
    let score: Double
    
    enum HighlightType: String, Codable {
        case structure = "Structure"
        case trend = "Trend"
        case momentum = "Momentum"
        case pattern = "Pattern"
        
        var icon: String {
            switch self {
            case .structure: return "building.2.fill"
            case .trend: return "chart.line.uptrend.xyaxis"
            case .momentum: return "bolt.fill"
            case .pattern: return "waveform.path.ecg"
            }
        }
        
        var color: Color {
            switch self {
            case .structure: return .blue
            case .trend: return .green
            case .momentum: return .orange
            case .pattern: return .purple
            }
        }
    }
}

// MARK: - Scout Story Store
/// Manages scout stories with persistence and FIFO eviction
@MainActor
final class ScoutStoryStore: ObservableObject {
    static let shared = ScoutStoryStore()
    
    @Published private(set) var stories: [ScoutStory] = []
    
    private let maxStories = 30
    private let fileURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("scout_stories.json")
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Unviewed stories count (for badge)
    var unviewedCount: Int {
        stories.filter { !$0.isViewed }.count
    }
    
    /// Add a new story (or update existing) - debounced to prevent UI flicker
    func addStory(_ story: ScoutStory) {
        // Remove existing for same symbol
        stories.removeAll { $0.symbol == story.symbol }
        
        // Add new at beginning
        stories.insert(story, at: 0)
        
        // Evict old stories (FIFO)
        if stories.count > maxStories {
            stories = Array(stories.prefix(maxStories))
        }
        
        // Debounce disk save (don't save every single story)
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: debounceWorkItem!)
    }
    
    private var debounceWorkItem: DispatchWorkItem?
    
    /// Add multiple stories from scout results
    func addStoriesFromScout(results: [(String, Double, Quote, OrionScoreResult)]) {
        for (symbol, _, quote, orionResult) in results {
            let highlights = buildHighlights(from: orionResult)
            
            let story = ScoutStory(
                id: UUID(),
                symbol: symbol,
                price: quote.c,
                changePercent: quote.dp ?? 0,
                orionScore: orionResult.score,
                signal: ScoutSignal.from(score: orionResult.score),
                highlights: highlights,
                scannedAt: Date(),
                isViewed: false
            )
            
            addStory(story)
        }
    }
    
    /// Mark a story as viewed
    func markViewed(_ storyId: UUID) {
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            stories[index].isViewed = true
            saveToDisk()
        }
    }
    
    /// Mark all as viewed
    func markAllViewed() {
        for i in stories.indices {
            stories[i].isViewed = true
        }
        saveToDisk()
    }
    
    /// Clear all stories
    func clearAll() {
        stories.removeAll()
        saveToDisk()
    }
    
    // MARK: - Helpers
    
    private func buildHighlights(from result: OrionScoreResult) -> [ScoutHighlight] {
        var highlights: [ScoutHighlight] = []
        
        // Structure
        highlights.append(ScoutHighlight(
            type: .structure,
            value: result.components.structureDesc ?? "Yapı",
            score: result.components.structure
        ))
        
        // Trend
        highlights.append(ScoutHighlight(
            type: .trend,
            value: result.components.trendDesc ?? "Trend",
            score: result.components.trend
        ))
        
        // Momentum
        highlights.append(ScoutHighlight(
            type: .momentum,
            value: result.components.momentumDesc ?? "Momentum",
            score: result.components.momentum
        ))
        
        // Pattern
        highlights.append(ScoutHighlight(
            type: .pattern,
            value: result.components.patternDesc ?? "Pattern",
            score: result.components.pattern
        ))
        
        return highlights
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            stories = try JSONDecoder().decode([ScoutStory].self, from: data)
            print(" ScoutStoryStore: \(stories.count) story yüklendi")
        } catch {
            print(" ScoutStoryStore: Load error - \(error.localizedDescription)")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(stories)
            try data.write(to: fileURL)
        } catch {
            print(" ScoutStoryStore: Save error - \(error.localizedDescription)")
        }
    }
}
