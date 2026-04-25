import Foundation
import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    let objectWillChange = ObservableObjectPublisher()
    
    @AppStorage("language") var language: String = "tr" {
        didSet {
            objectWillChange.send()
        }
    }
    
    private init() {}
    
    func localized(_ key: String) -> String {
        let dict = language == "en" ? en : tr
        return dict[key] ?? key
    }
    
    // MARK: - Dictionary
    
    private let tr: [String: String] = [
        // Settings - General
        "settings_title": "Ayarlar",
        "general_section": "GENEL",
        "language": "Dil",
        "dark_mode": "Karanlık Mod",
        "currency": "Para Birimi",
        "starting_balance": "Başlangıç Bakiyesi",
        "balance_placeholder": "Bakiye",
        
        // Settings - AI Engine
        "ai_engine_section": "YAPAY ZEKA MOTORU",
        "risk_tolerance": "Risk Toleransı",
        "max_positions": "Maks. Pozisyon",
        "active_strategies": "Aktif Stratejiler",
        "risk_low": "Düşük",
        "risk_medium": "Orta",
        "risk_high": "Yüksek",
        
        // Settings - Notifications
        "notifications_section": "BİLDİRİMLER",
        "all_notifications": "Tüm Bildirimler",
        "price_alerts": "Fiyat Alarmları",
        "price_alerts_settings": "Fiyat Alarmları Ayarları",
        
        // Settings - Security
        "security_section": "GÜVENLİK",
        "face_id": "Face ID",
        "privacy_policy": "Gizlilik Politikası",
        "change_password": "Şifre Değiştir",
        
        // Settings - Developer
        "developer_section": "GELİŞTİRİCİ",
        "system_check": "Sistem Kontrolü",
        "api_key": "API Key",
        
        // Settings - Footer
        "logout": "Çıkış Yap",
        "close": "Kapat",
        "done": "Tamam",
        
        // Orion Score Card
        "orion_score_title": "ARGUS ORION SKORU",
        "analyzing": "Orion Analizi Yapılıyor...",
        "fundamental": "Argus Makro", // Renamed
        "technical": "Teknik",
        "macro": "Aether Global", // Renamed
        
        // Orion Details
        "orion_story_title": "Neden Orion?",
        "orion_story_text": "Adını Avcı takımyıldızından alan Orion, piyasa evrenindeki fırsatları avlamak için tasarlandı. Orion Kuşağı'nın üç parlak yıldızı gibi, sistemimiz de üç temel sütuna dayanır: Argus Makro (Temel Analiz), Teknik Analiz ve Aether Global (Makroekonomi).",
        "orion_methodology_title": "Metodoloji",
        "orion_argus_desc": "Şirketin finansal sağlığını, karlılığını ve büyüme potansiyelini değerlendirir. Skorun temel taşıdır.",
        "orion_tech_desc": "Giriş ve çıkış için en iyi zamanlamayı belirlemek adına fiyat hareketlerini, trendleri ve momentumu analiz eder.",
        "orion_aether_desc": "Piyasa risk iştahını ölçmek için küresel ekonomik iklimi (faiz oranları, enflasyon) değerlendirir.",
        "missing_data_warning": "Eksik Veri",
        
        // Signals View
        "signals_title": "Sinyaller",
        "ai_signals_header": "Yapay Zeka Sinyalleri",
        "scan_market": "Piyasayı Tara",
        "scanning": "Piyasa Taranıyor...",
        "no_signals": "Henüz Sinyal Yok",
        "strong_buy_signals": "Güçlü AL Sinyalleri 🚀",
        "buy_signals": "AL Sinyalleri 📈",
        "sell_signals": "SAT Sinyalleri 🔻",
        "wait_signals": "BEKLE Sinyalleri ⏸️",
        
        // Widget
        "widget_opportunities": "FIRSATLAR",
        "widget_portfolio": "PORTFÖY",
        "widget_open": "Açık",
        "widget_risk_high": "Risk İştahı Yüksek",
        "widget_risk_off": "Riskten Kaçış",
        "widget_neutral": "Nötr Piyasa",
        "widget_no_signal": "Sinyal Yok"
    ]
    
    private let en: [String: String] = [
        // Settings - General
        "settings_title": "Settings",
        "general_section": "GENERAL",
        "language": "Language",
        "dark_mode": "Dark Mode",
        "currency": "Currency",
        "starting_balance": "Starting Balance",
        "balance_placeholder": "Balance",
        
        // Settings - AI Engine
        "ai_engine_section": "AI ENGINE",
        "risk_tolerance": "Risk Tolerance",
        "max_positions": "Max Positions",
        "active_strategies": "Active Strategies",
        "risk_low": "Low",
        "risk_medium": "Medium",
        "risk_high": "High",
        
        // Settings - Notifications
        "notifications_section": "NOTIFICATIONS",
        "all_notifications": "All Notifications",
        "price_alerts": "Price Alerts",
        "price_alerts_settings": "Price Alerts Settings",
        
        // Settings - Security
        "security_section": "SECURITY",
        "face_id": "Face ID",
        "privacy_policy": "Privacy Policy",
        "change_password": "Change Password",
        
        // Settings - Developer
        "developer_section": "DEVELOPER",
        "system_check": "System Check",
        "api_key": "API Key",
        
        // Settings - Footer
        "logout": "Log Out",
        "close": "Close",
        "done": "Done",
        
        // Orion Score Card
        "orion_score_title": "ARGUS ORION SCORE",
        "analyzing": "Analyzing Orion...",
        "fundamental": "Argus Macro", // Renamed from Fund.
        "technical": "Technical",
        "macro": "Aether Global", // Renamed from Macro
        
        // Orion Details
        "orion_story_title": "Why Orion?",
        "orion_story_text": "Named after the Hunter constellation, Orion is designed to spot opportunities in the vast market universe. Just as Orion's Belt consists of three bright stars, our system relies on three core pillars: Argus Macro (Fundamental), Technical Analysis, and Aether Global (Macroeconomics).",
        "orion_methodology_title": "Methodology",
        "orion_argus_desc": "Evaluates the company's financial health, profitability, and growth potential. It's the bedrock of the score.",
        "orion_tech_desc": "Analyzes price action, trends, and momentum to determine the best timing for entry or exit.",
        "orion_aether_desc": "Assesses the global economic climate (interest rates, inflation) to gauge market risk appetite.",
        "missing_data_warning": "Missing Data",
        
        // Signals View
        "signals_title": "Signals",
        "ai_signals_header": "AI Signals",
        "scan_market": "Scan Market",
        "scanning": "Scanning Market...",
        "no_signals": "No Signals Yet",
        "strong_buy_signals": "Strong BUY Signals 🚀",
        "buy_signals": "BUY Signals 📈",
        "sell_signals": "SELL Signals 🔻",
        "wait_signals": "HOLD Signals ⏸️",
        
        // Widget
        "widget_opportunities": "OPPORTUNITIES",
        "widget_portfolio": "PORTFOLIO",
        "widget_open": "Open",
        "widget_risk_high": "Risk On",
        "widget_risk_off": "Risk Off",
        "widget_neutral": "Neutral Market",
        "widget_no_signal": "No Signal"
    ]
}

extension String {
    func localized() -> String {
        return LocalizationManager.shared.localized(self)
    }
}
