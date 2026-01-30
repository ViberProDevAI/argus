import Foundation
import SwiftUI

// MARK: - Shared UI Models for Orion

enum TimeframeMode: String, CaseIterable {
    case m5 = "5M"
    case m15 = "15M"
    case h1 = "1H"
    case h4 = "4H"
    case daily = "1D"
    case weekly = "1W"
    
    var displayLabel: String { rawValue }
    
    var apiParam: String {
        switch self {
        case .m5: return "5m"
        case .m15: return "15m"
        case .h1: return "1h"
        case .h4: return "4h"
        case .daily: return "1d"
        case .weekly: return "1w"
        }
    }

    /// API string format for MarketDataStore (matches OrionStore timeframe keys)
    var apiString: String {
        switch self {
        case .m5: return "5m"
        case .m15: return "15m"
        case .h1: return "1h"
        case .h4: return "4h"
        case .daily: return "1G"  // MarketDataStore uses "1G" for daily
        case .weekly: return "1W"
        }
    }
}

enum SignalStatus {
    case positive, negative, neutral
}

enum CircuitNode: Equatable {
    case trend, momentum, structure, pattern, cpu, output
    
    var title: String {
        switch self {
        case .trend: return "TREND"
        case .momentum: return "MOMENTUM"
        case .structure: return "YAPI"
        case .pattern: return "FORMASYON"
        case .cpu: return "KONSENSUS"
        case .output: return "SONUÇ"
        }
    }
    
    func educationalContent(for orion: OrionScoreResult) -> String {
        switch self {
        case .trend:
            return """
            **METODOLOJİ: TREND TAKİBİ**
            
            Trend analizi, fiyatın "en az direnç gösteren yolunu" tespit eder. Argus, üç ana hareketli ortalamayı (SMA 20, 50, 200) ve bunların birbirine olan hizalanmasını (Alignment) inceler.
            
            **KULLANILAN GÖSTERGELER:**
            • **SMA 200 (Ana Yön):** Fiyat bunun üzerindeyse uzun vadeli trend pozitiftir. Altındaysa ayı piyasası hakimdir.
            • **Altın Kesişim (Golden Cross):** SMA 50'nin SMA 200'ü yukarı kesmesi, boğa piyasasının en güçlü sinyallerinden biridir.
            • **ADX (Trend Gücü):** Yön ne olursa olsun, trendin gücünü ölçer. 25 üzeri ADX, güçlü bir trendi işaret eder.
            
            💡 **PRO TIP:** Trend dostunuzdur, ancak "düzeltme" (pullback) ile "dönüş" (reversal) arasındaki farkı anlamak kritiktir. ADX düşüyorsa trend zayıflıyor olabilir.
            """
            
        case .momentum:
            return """
            **METODOLOJİ: MOMENTUM & HIZ**
            
            Momentum, bir aracın gaz pedalına benzer. Fiyat artıyor olabilir, ancak "ivme" azalıyor mu? Momentum analizi bu soruyu cevaplar.
            
            **TEMEL KAVRAMLAR:**
            • **RSI (Göreceli Güç):** 70 üzeri "Aşırı Alım" (Fiyat pahalı), 30 altı "Aşırı Satım" (Fiyat ucuz) bölgesidir. Ancak güçlü trendlerde RSI uzun süre 70 üzerinde kalabilir; bu bir güç göstergesidir, hemen sat sinyali değildir.
            • **Uyumsuzluk (Divergence):** Fiyat yeni zirve yaparken RSI yapamıyorsa (Negatif Uyumsuzluk), düşüş yakındır.
            
            💡 **PRO TIP:** RSI 50 seviyesi "Boğa/Ayı Kontrol Bölgesi"dir. 50'nin üzerinde kalıcılık, alıcıların iştahlı olduğunu gösterir.
            """
            
        case .structure:
            return """
            **METODOLOJİ: PİYASA YAPISI & HACİM**
            
            Fiyat hareketi (Price Action) ve Hacim (Volume) arasındaki ilişki, hareketin gerçekliğini test eder.
            
            **ANALİZ MANTIĞI:**
            • **Hacim Onayı:** Fiyat artarken hacim de artıyorsa, yükseliş "sağlıklıdır" ve kurumsal katılımcılar tarafından destekleniyordur.
            • **Destek/Direnç Kanalları:** Fiyatın tarihsel olarak tepki verdiği bölgelerdir.
            • **Anomali:** Fiyat artarken hacim düşüyorsa, yükseliş "sahte" (Fakeout) olabilir.
            
            💡 **PRO TIP:** Hacimsiz yükselişler genellikle satış fırsatıdır. Büyük mumlar + Yüksek hacim = Kurumsal Ayak İzi.
            """
            
        case .pattern:
            return """
            **METODOLOJİ: FORMASYON TESPİTİ**
            
            Piyasalar insan psikolojisiyle hareket eder ve bu psikoloji grafiklerde tekrar eden geometrik şekiller (Formasyonlar) oluşturur.
            
            **ARANAN YAPILAR:**
            • **Dönüş Formasyonları:** İkili Dip, OBO (Omuz Baş Omuz), Ters OBO. Trendin değişeceğini haber verir.
            • **Devam Formasyonları:** Bayrak (Flag), Flama (Pennant). Trendin kısa bir moladan sonra devam edeceğini gösterir.
            
            💡 **PRO TIP:** Formasyonlar "gerçekleşmeden" değil, "kırılım" (breakout) teyidi alındıktan sonra işlem yapılmalıdır. Erken girmek risklidir.
            """
            
        case .cpu:
            return """
            **METODOLOJİ: KONSENSUS MOTORU**
            
            Konsensus, Argus'un beynidir. Tüm alt sistemlerden (Trend, Momentum, Yapı, Formasyon) gelen sinyalleri toplar, her birine güven skoruna göre ağırlık verir ve nihai bir "Piyasa Görüşü" oluşturur.
            
            **NASIL HESAPLANIR?**
            Her modül 0-100 arası bir skor üretir. Konsensus, bu skorların ağırlıklı ortalamasını alır. 50 puan "Nötr" (Kararsız) bölgedir. 50'den uzaklaştıkça sinyalin gücü artar.
            """
            
        case .output:
            return "Sonuç ekranı."
        }
    }
}
