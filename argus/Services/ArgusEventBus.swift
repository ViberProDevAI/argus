import Foundation

// MARK: - Argus Event Bus (Argus 3.0)
/// Modüller arası haberleşme katmanı.
/// Trade açılınca, kapanınca veya ağırlık değişince ilgili modülleri bilgilendirir.

// MARK: - Event Types

enum ArgusEvent: Sendable {
    case tradeOpened(symbol: String, price: Double, tradeId: UUID, reason: String)
    case tradeClosed(tradeId: UUID, symbol: String, pnlPercent: Double)
    case lessonLearned(tradeId: UUID, lesson: String)
    case weightsUpdated(module: String, oldWeight: Double, newWeight: Double, reason: String?)
}

// MARK: - Subscriber Protocol

protocol ArgusEventSubscriber: AnyObject {
    func onEvent(_ event: ArgusEvent)
}

// MARK: - Event Bus Actor

actor ArgusEventBus {
    static let shared = ArgusEventBus()
    
    private var subscribers: [UUID: WeakSubscriber] = [:]
    
    private init() {}
    
    // MARK: - Subscription
    
    /// Subscribe to events. Returns a subscription ID for later unsubscription.
    func subscribe(_ subscriber: ArgusEventSubscriber) -> UUID {
        let id = UUID()
        subscribers[id] = WeakSubscriber(subscriber)
        print("📡 EventBus: New subscriber registered (Total: \(subscribers.count))")
        return id
    }
    
    /// Unsubscribe using the subscription ID.
    func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }
    
    // MARK: - Publishing
    
    /// Publishes an event to all subscribers.
    func publish(_ event: ArgusEvent) {
        // Clean up dead references
        subscribers = subscribers.filter { $0.value.value != nil }
        
        for (_, weakSub) in subscribers {
            if let sub = weakSub.value {
                // Dispatch to main thread for UI updates
                Task { @MainActor in
                    sub.onEvent(event)
                }
            }
        }
        
        // Log the event
        switch event {
        case .tradeOpened(let symbol, let price, _, _):
            print("📡 EventBus: Trade Opened - \(symbol) @ \(price)")
        case .tradeClosed(_, let symbol, let pnl):
            print("📡 EventBus: Trade Closed - \(symbol) PnL: \(String(format: "%.2f", pnl))%")
        case .lessonLearned(_, let lesson):
            print("📡 EventBus: Lesson - \(lesson.prefix(50))...")
        case .weightsUpdated(let module, let old, let new, _):
            print("📡 EventBus: Weight Updated - \(module): \(old) → \(new)")
        }
    }
    
    // MARK: - Convenience Publishers
    
    /// Convenience method to publish trade opened event and log to ledger.
    func publishTradeOpened(symbol: String, price: Double, reason: String, dominantSignal: String? = nil) {
        let tradeId = ArgusLedger.shared.openTrade(
            symbol: symbol,
            price: price,
            reason: reason,
            dominantSignal: dominantSignal
        )
        publish(.tradeOpened(symbol: symbol, price: price, tradeId: tradeId, reason: reason))
    }
    
    /// Convenience method to publish trade closed event and log to ledger.
    func publishTradeClosed(tradeId: UUID, exitPrice: Double, symbol: String, pnlPercent: Double) {
        ArgusLedger.shared.closeTrade(tradeId: tradeId, exitPrice: exitPrice)
        publish(.tradeClosed(tradeId: tradeId, symbol: symbol, pnlPercent: pnlPercent))
    }
    
    /// Convenience method to publish lesson learned and log to ledger.
    func publishLesson(tradeId: UUID, lesson: String, deviation: Double?, weightChanges: [String: Double]?) {
        ArgusLedger.shared.recordLesson(tradeId: tradeId, lesson: lesson, deviationPercent: deviation, weightChanges: weightChanges)
        publish(.lessonLearned(tradeId: tradeId, lesson: lesson))
    }
}

// MARK: - Weak Reference Wrapper

private class WeakSubscriber {
    weak var value: ArgusEventSubscriber?
    
    init(_ value: ArgusEventSubscriber) {
        self.value = value
    }
}
