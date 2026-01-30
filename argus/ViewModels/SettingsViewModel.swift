import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    // MARK: - General
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    @Published var currency: String {
        didSet { UserDefaults.standard.set(currency, forKey: "currency") }
    }
    
    // MARK: - Trading Preferences
    @Published var defaultTradeAmountPercentage: Double {
        didSet { UserDefaults.standard.set(defaultTradeAmountPercentage, forKey: "defaultTradeAmountPercentage") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    
    // MARK: - Privacy & Security
    @Published var isFaceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(isFaceIDEnabled, forKey: "isFaceIDEnabled") }
    }
    @Published var shareAnalytics: Bool {
        didSet { UserDefaults.standard.set(shareAnalytics, forKey: "shareAnalytics") }
    }
    
    // MARK: - AI Engine Preferences
    @Published var riskTolerance: RiskTolerance {
        didSet { UserDefaults.standard.set(riskTolerance.rawValue, forKey: "riskTolerance") }
    }
    @Published var maxOpenPositions: Int {
        didSet { UserDefaults.standard.set(maxOpenPositions, forKey: "maxOpenPositions") }
    }
    @Published var aiStrategies: [String: Bool] {
        didSet { UserDefaults.standard.set(aiStrategies, forKey: "aiStrategies") }
    }
    
    // Data Collection (User Preference)
    @Published var isDataCollectionEnabled: Bool {
        didSet { UserDefaults.standard.set(isDataCollectionEnabled, forKey: "isDataCollectionEnabled") }
    }
    
    // Phoenix Timeframe Preference
    @Published var phoenixTimeframe: PhoenixTimeframe {
        didSet { UserDefaults.standard.set(phoenixTimeframe.rawValue, forKey: "phoenixTimeframe") }
    }
    
    // MARK: - API
    // MARK: - API (Linked to KeyStore)
    @Published var apiKey: String = ""
    @Published var fredApiKey: String = "" {
        didSet {
            Task { @MainActor in
                APIKeyStore.shared.setKey(provider: .fred, key: fredApiKey)
            }
        }
    }
    @Published var isApiKeyVisible: Bool = false
    
    // MARK: - Legal Documents (Static Data)
    // LegalDocument struct is defined in Models.swift
    let privacyPolicy = LegalDocument(title: "Gizlilik Politikası", content: "Bu gizlilik politikası, kişisel verilerinizin nasıl toplandığını, kullanıldığını ve korunduğunu açıklar. Uygulamamızı kullanarak, verilerinizin bu politikaya uygun olarak işlenmesini kabul etmiş olursunuz.\n\n1. Veri Toplama: Uygulama, işlem geçmişinizi ve tercihlerinizi yerel cihazınızda saklar.\n2. Üçüncü Taraflar: Piyasa verileri için üçüncü taraf API sağlayıcıları (örn. Finnhub) kullanılmaktadır.\n3. Güvenlik: Verileriniz endüstri standardı şifreleme yöntemleri ile korunmaktadır.")
    
    let termsOfUse = LegalDocument(title: "Kullanım Koşulları", content: "Bu uygulamayı indirerek ve kullanarak aşağıdaki koşulları kabul etmiş sayılırsınız.\n\n1. Amaç: Bu uygulama sadece eğitim ve simülasyon amaçlıdır. Gerçek para ile işlem yapılmaz.\n2. Sorumluluk Reddi: Uygulama tarafından sağlanan sinyaller ve veriler yatırım tavsiyesi değildir. Finansal kayıplardan geliştirici sorumlu tutulamaz.\n3. Değişiklikler: Geliştirici, uygulama özelliklerini önceden haber vermeksizin değiştirme hakkını saklı tutar.")
    
    let riskDisclosure = LegalDocument(title: "Risk Bildirimi", content: "Finansal piyasalarda işlem yapmak yüksek risk içerir ve tüm yatırımcılar için uygun olmayabilir.\n\nKaldıraçlı işlem yapmak, yatırdığınız sermayenin tamamını veya daha fazlasını kaybetmenize neden olabilir. İşlem yapmaya karar vermeden önce yatırım hedeflerinizi, deneyim seviyenizi ve risk iştahınızı dikkatlice değerlendirmelisiniz.\n\nBu uygulama bir 'Demo' ortamıdır ve gerçek piyasa koşullarını birebir yansıtmayabilir.")
    
    init() {
        self.language = UserDefaults.standard.string(forKey: "language") ?? "tr"
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
        self.currency = UserDefaults.standard.string(forKey: "currency") ?? "USD"
        
        let savedTradeAmount = UserDefaults.standard.double(forKey: "defaultTradeAmountPercentage")
        self.defaultTradeAmountPercentage = savedTradeAmount == 0 ? 10.0 : savedTradeAmount
        
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
        self.shareAnalytics = UserDefaults.standard.object(forKey: "shareAnalytics") as? Bool ?? true
        
        // AI Init
        let savedRisk = UserDefaults.standard.string(forKey: "riskTolerance") ?? "Orta"
        self.riskTolerance = RiskTolerance(rawValue: savedRisk) ?? .medium
        
        let savedMaxPos = UserDefaults.standard.integer(forKey: "maxOpenPositions")
        self.maxOpenPositions = savedMaxPos == 0 ? 300 : savedMaxPos
        
        self.aiStrategies = UserDefaults.standard.dictionary(forKey: "aiStrategies") as? [String: Bool] ?? [
            "Trend Takipçisi": true,
            "Ortalamaya Dönüş": true,
            "Kırılım Yakalayıcı": false
        ]
        
        self.isDataCollectionEnabled = UserDefaults.standard.object(forKey: "isDataCollectionEnabled") as? Bool ?? true
        
        // Phoenix Init
        let savedPTF = UserDefaults.standard.string(forKey: "phoenixTimeframe") ?? "Otomatik"
        self.phoenixTimeframe = PhoenixTimeframe(rawValue: savedPTF) ?? .auto
        
        // KeyStore Entegrasyonu (Safe Init)
        self.loadKeys()
        
        // Use Closure instead of Selector to avoid @objc issues during init
        NotificationCenter.default.addObserver(forName: .argusKeyStoreDidUpdate, object: nil, queue: .main) { [weak self] _ in
            self?.loadKeys()
        }
        
    }

    func loadKeys() {
        Task { @MainActor in
            if let fred = APIKeyStore.shared.getKey(for: .fred) {
                if self.fredApiKey != fred { self.fredApiKey = fred }
            }
        }
    }
}

enum RiskTolerance: String, CaseIterable, Identifiable {
    case low = "Düşük"
    case medium = "Orta"
    case high = "Yüksek"
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .low: return "risk_low".localized()
        case .medium: return "risk_medium".localized()
        case .high: return "risk_high".localized()
        }
    }
}
