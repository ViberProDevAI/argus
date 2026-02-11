import Foundation

/// Capital Markets Board of Turkey (SPK) Compliance Engine
/// Manages strict legal disclaimers and investment advice warnings.
final class SPKRegulatoryEngine: Sendable {
    static let shared = SPKRegulatoryEngine()
    
    private init() {}
    
    // MARK: - Legal Texts
    
    /// Standard SPK Disclaimer (YASAL UYARI)
    /// Must be visible on all investment related screens and reports.
    let standardDisclaimer = """
    YASAL UYARI:
    Burada yer alan yatırım bilgi, yorum ve tavsiyeleri yatırım danışmanlığı kapsamında değildir. Yatırım danışmanlığı hizmeti; aracı kurumlar, portföy yönetim şirketleri, mevduat kabul etmeyen bankalar ile müşteri arasında imzalanacak yatırım danışmanlığı sözleşmesi çerçevesinde sunulmaktadır. Burada yer alan yorum ve tavsiyeler, yorum ve tavsiyede bulunanların kişisel görüşlerine dayanmaktadır. Bu görüşler mali durumunuz ile risk ve getiri tercihlerinize uygun olmayabilir. Bu nedenle, sadece burada yer alan bilgilere dayanılarak yatırım kararı verilmesi beklentilerinize uygun sonuçlar doğurmayabilir.
    """
    
    /// Short Warning for UI Constraints
    let shortDisclaimer = "Yatırım Tavsiyesi Değildir (YTD)."
    
    /// High Risk Warning (For Derivatives/Crypto/FX)
    let highRiskWarning = """
    RİSK BİLDİRİMİ:
    Kaldıraçlı işlem ve kripto varlık piyasaları YÜKSEK RİSK içerir. Paranızı tamamen kaybedebilirsiniz.
    """
    
    // MARK: - Compliance Checks
    
    /// Checks if the content contains the required disclaimer.
    /// If not, appends it.
    func ensureCompliance(content: String, isHighRisk: Bool = false) -> String {
        var compliantContent = content
        
        // 1. Check for Standard Disclaimer
        if !content.contains("YASAL UYARI") && !content.contains("Yatırım Tavsiyesi Değildir") {
            compliantContent += "\n\n" + standardDisclaimer
        }
        
        // 2. Check for High Risk Warning
        if isHighRisk && !content.contains("RİSK BİLDİRİMİ") {
            compliantContent = highRiskWarning + "\n\n" + compliantContent
        }
        
        return compliantContent
    }
    
    /// Returns the appropriate badge/text for a given asset class
    func getRiskBadge(for assetType: String) -> String {
        switch assetType.lowercased() {
        case "crypto", "kripto", "forex", "kaldıraç":
            return "YÜKSEK RİSK"
        case "stock", "bist", "hisse":
            return "YTD"
        default:
            return "YTD"
        }
    }
}
