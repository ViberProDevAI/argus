import Foundation

// MARK: - Report Scheduler
/// Otomatik rapor oluşturma zamanlayıcısı
/// Gün sonu ve hafta sonu raporlarını otomatik üretir

actor ReportScheduler {
    static let shared = ReportScheduler()

    private var dailyTimer: Timer?
    private var weeklyTimer: Timer?
    private var isRunning = false

    private let storagePath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("report_schedule")
    }()

    private init() {
        try? FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
    }

    // MARK: - Schedule State

    struct ScheduleState: Codable {
        var lastDailyReport: Date?
        var lastWeeklyReport: Date?
        var isEnabled: Bool

        static var `default`: ScheduleState {
            ScheduleState(lastDailyReport: nil, lastWeeklyReport: nil, isEnabled: true)
        }
    }

    // MARK: - Public API

    /// Scheduler'ı başlat
    func start() async {
        guard !isRunning else { return }
        isRunning = true

        print("📅 ReportScheduler başlatıldı")

        // İlk kontrol - bekleyen rapor var mı?
        await checkPendingReports()

        // Her saat kontrol et (market kapanışı için)
        await scheduleHourlyCheck()
    }

    /// Scheduler'ı durdur
    func stop() {
        isRunning = false
        dailyTimer?.invalidate()
        weeklyTimer?.invalidate()
        print("📅 ReportScheduler durduruldu")
    }

    /// Manuel olarak günlük rapor oluştur
    func generateDailyReportNow() async -> String {
        let report = await generateDailyReport()
        await updateState { state in
            state.lastDailyReport = Date()
        }
        return report
    }

    /// Manuel olarak haftalık rapor oluştur
    func generateWeeklyReportNow() async -> String {
        let report = await generateWeeklyReport()
        await updateState { state in
            state.lastWeeklyReport = Date()
        }
        return report
    }

    /// Son raporları getir
    func getLatestReports() async -> (daily: String?, weekly: String?) {
        let reports = await ReportEngine.shared.getRecentReports(limit: 10)
        let daily = reports.first { $0.type == .daily }?.content
        let weekly = reports.first { $0.type == .weekly }?.content
        return (daily, weekly)
    }

    // MARK: - Scheduling Logic

    private func scheduleHourlyCheck() async {
        // Her saat başı kontrol (bu basit bir implementasyon)
        // Production'da BackgroundTasks kullanılmalı
        Task {
            while isRunning {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000) // 1 saat
                await checkScheduledReports()
            }
        }
    }

    private func checkPendingReports() async {
        let state = await loadState()
        let calendar = Calendar.current
        let now = Date()

        // Bugün için günlük rapor oluşturulmuş mu?
        if let lastDaily = state.lastDailyReport {
            if !calendar.isDateInToday(lastDaily) && shouldGenerateDailyReport() {
                print("📅 Bekleyen günlük rapor tespit edildi, oluşturuluyor...")
                _ = await generateDailyReportNow()
            }
        } else if shouldGenerateDailyReport() {
            print("📅 İlk günlük rapor oluşturuluyor...")
            _ = await generateDailyReportNow()
        }

        // Bu hafta için haftalık rapor oluşturulmuş mu?
        if let lastWeekly = state.lastWeeklyReport {
            if !calendar.isDate(lastWeekly, equalTo: now, toGranularity: .weekOfYear) && shouldGenerateWeeklyReport() {
                print("📅 Bekleyen haftalık rapor tespit edildi, oluşturuluyor...")
                _ = await generateWeeklyReportNow()
            }
        } else if shouldGenerateWeeklyReport() {
            print("📅 İlk haftalık rapor oluşturuluyor...")
            _ = await generateWeeklyReportNow()
        }
    }

    private func checkScheduledReports() async {
        guard await loadState().isEnabled else { return }

        // Günlük rapor: Saat 18:00-19:00 arası (market kapanışı sonrası)
        if shouldGenerateDailyReport() {
            let state = await loadState()
            if let lastDaily = state.lastDailyReport {
                if !Calendar.current.isDateInToday(lastDaily) {
                    print("📅 Günlük rapor zamanı geldi")
                    _ = await generateDailyReportNow()
                    await sendNotification(title: "Günlük Rapor Hazır", body: "Bugünün analiz raporu oluşturuldu.")
                }
            } else {
                _ = await generateDailyReportNow()
            }
        }

        // Haftalık rapor: Cuma 18:00-19:00 arası
        if shouldGenerateWeeklyReport() {
            let state = await loadState()
            let calendar = Calendar.current
            if let lastWeekly = state.lastWeeklyReport {
                if !calendar.isDate(lastWeekly, equalTo: Date(), toGranularity: .weekOfYear) {
                    print("📅 Haftalık rapor zamanı geldi")
                    _ = await generateWeeklyReportNow()
                    await sendNotification(title: "Haftalık Rapor Hazır", body: "Bu haftanın performans raporu oluşturuldu.")
                }
            } else {
                _ = await generateWeeklyReportNow()
            }
        }
    }

    private func shouldGenerateDailyReport() -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // Hafta içi (Pazartesi-Cuma) - saat kısıtı yok, rapor her saat oluşturulabilir
        let isWeekday = weekday >= 2 && weekday <= 6
        
        return isWeekday
    }
    
    private func shouldGenerateWeeklyReport() -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // Hafta içi (Pazartesi-Cuma) - saat kısıtı yok, rapor her saat oluşturulabilir
        // Not: Piyasa alım-satım timing'i ayrıdır
        let isWeekday = weekday >= 2 && weekday <= 6
        
        return isWeekday
    }

    // MARK: - Report Generation

    private func generateDailyReport() async -> String {
        // Collect data from MainActor-isolated PortfolioStore
        let trades = await MainActor.run { PortfolioStore.shared.transactions }
        let decisions = AgoraTraceStore.shared.recentTraces

        // Get Aether macro score
        let macroResult = await MacroRegimeService.shared.evaluate()
        let aetherScore = macroResult.legacyRating.numericScore

        let report = await ReportEngine.shared.generateDailyReport(
            date: Date(),
            trades: trades,
            decisions: decisions,
            atmosphere: (aether: aetherScore, demeter: nil)
        )

        // Also generate Alkindus insights
        _ = await AlkindusInsightGenerator.shared.generateDailyInsights()

        return report
    }

    private func generateWeeklyReport() async -> String {
        // Collect data from MainActor-isolated PortfolioStore
        let trades = await MainActor.run { PortfolioStore.shared.transactions }
        let decisions = AgoraTraceStore.shared.recentTraces

        return await ReportEngine.shared.generateWeeklyReport(
            date: Date(),
            trades: trades,
            decisions: decisions
        )
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) async {
        // NotificationCenter'a bildirim gönder (UI tarafından dinlenecek)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .reportGenerated,
                object: nil,
                userInfo: ["title": title, "body": body]
            )
        }
    }

    // MARK: - State Persistence

    private func loadState() async -> ScheduleState {
        let fileURL = storagePath.appendingPathComponent("schedule_state.json")
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(ScheduleState.self, from: data) else {
            return .default
        }
        return state
    }

    private func updateState(_ update: (inout ScheduleState) -> Void) async {
        var state = await loadState()
        update(&state)

        let fileURL = storagePath.appendingPathComponent("schedule_state.json")
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let reportGenerated = Notification.Name("reportGenerated")
}

// MARK: - AgoraTraceStore (Helper)
/// ReportScheduler'ın decision trace'lere erişimi için

class AgoraTraceStore {
    static let shared = AgoraTraceStore()

    private var traces: [AgoraTrace] = []
    private let maxTraces = 500

    private init() {}

    var recentTraces: [AgoraTrace] {
        traces
    }

    func add(_ trace: AgoraTrace) {
        traces.append(trace)
        if traces.count > maxTraces {
            traces.removeFirst(traces.count - maxTraces)
        }
    }

    func tracesForDate(_ date: Date) -> [AgoraTrace] {
        traces.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
    }

    func tracesForWeek(containing date: Date) -> [AgoraTrace] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return []
        }
        return traces.filter { $0.timestamp >= weekStart && $0.timestamp <= date }
    }
}
