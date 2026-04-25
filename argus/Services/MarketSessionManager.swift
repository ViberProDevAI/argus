import Foundation
import Combine
import SwiftUI

protocol MarketSessionService {
    func isMarketOpen(now: Date) -> Bool
    func lastSessionClose(now: Date) -> Date
}

class MarketSessionManager: MarketSessionService, ObservableObject {
    static let shared = MarketSessionManager()
    
    // Default to US Market Hours (New York Time)
    // 09:30 - 16:00
    private let calendar = Calendar(identifier: .gregorian)
    private let timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
    
    func isMarketOpen(now: Date = Date()) -> Bool {
        // 1. Check Weekend
        guard !calendar.isDateInWeekend(now) else { return false }
        
        // 2. Check Time in NY
        var calendar = self.calendar
        calendar.timeZone = self.timeZone
        
        let components = calendar.dateComponents([.hour, .minute], from: now)
        guard let hour = components.hour, let minute = components.minute else { return false }
        
        // Convert to minutes from midnight
        let minutesNow = hour * 60 + minute
        
        let marketOpen = 9 * 60 + 30  // 09:30
        let marketClose = 16 * 60     // 16:00
        
        return minutesNow >= marketOpen && minutesNow < marketClose
    }
    
    func lastSessionClose(now: Date = Date()) -> Date {
        var calendar = self.calendar
        calendar.timeZone = self.timeZone
        
        // If today is weekend or before market open, last close was yesterday (or Friday)
        // Ideally we just want a reference timestamp to check if data is stale.
        // For simplicity, return the previous 16:00 NY time.
        
        // Start with today 16:00
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 16
        components.minute = 0
        components.second = 0
        
        guard let todayClose = calendar.date(from: components) else { return now }
        
        if now > todayClose && !calendar.isDateInWeekend(now) {
            // If we are past 16:00 today and it's a weekday, last close is today.
            return todayClose
        }
        
        // Otherwise, go back day by day until we find a weekday
        var checkDate = calendar.date(byAdding: .day, value: -1, to: todayClose)!
        while calendar.isDateInWeekend(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        return checkDate
    }
    // MARK: - Session Control
    @Published var isLiveSessionActive = false
    private var sessionTimer: Timer?
    
    func startSession() {
        print("⏰ MarketSessionManager: Oturum başlatılıyor...")
        isLiveSessionActive = true
        startTimer()
    }
    
    func stopSession() {
        print("⏰ MarketSessionManager: Oturum durduruluyor...")
        isLiveSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    private func startTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // Tick logic or notification if needed
        }
    }
}
