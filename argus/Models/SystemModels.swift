import Foundation

// MARK: - Enums
// SignalAction moved to HeimdallTypes.swift

struct ScoutLog: Identifiable, Sendable {
    let id = UUID()
    let symbol: String
    let status: String // "ONAYLI", "RED", "BEKLE"
    let reason: String
    let score: Double
    let timestamp: Date = Date()
}

// MARK: - System Education Model
enum ArgusSystemEntity: String, CaseIterable, Identifiable {
    case argus = "Argus"
    case aether = "Aether"
    case orion = "Orion"
    case demeter = "Demeter"
    case atlas = "Atlas"
    case hermes = "Hermes"
    case poseidon = "Poseidon"
    case corse = "Corse"
    case pulse = "Pulse"
    case shield = "Shield"
    case council = "Konsey"
    
    var id: String { rawValue }
    
    var color: String {
        switch self {
        case .argus: return "Blue"
        case .aether: return "Cyan"
        case .orion: return "Purple"
        case .demeter: return "Green"
        case .atlas: return "Indigo"
        case .hermes: return "Pink"
        case .poseidon: return "Teal"
        case .corse: return "Blue"
        case .pulse: return "Purple"
        case .shield: return "Green"
        case .council: return "Gold"
        }
    }
    
    /// Custom asset icon name (neon icons from Assets.xcassets)
    var assetIcon: String? {
        switch self {
        case .orion: return "OrionIcon"
        case .aether: return "AetherIcon"
        case .atlas: return "AtlasIcon"
        case .hermes: return "HermesIcon"
        case .demeter: return "DemeterIcon"
        case .poseidon: return "PoseidonIcon"
        default: return nil
        }
    }

    /// SF Symbol fallback icon
    var icon: String {
        switch self {
        case .argus: return "eye.trianglebadge.exclamationmark.fill"
        case .aether: return "cloud.fog.fill"
        case .orion: return "scope"
        case .demeter: return "leaf.fill"
        case .atlas: return "globe.europe.africa.fill"
        case .hermes: return "newspaper.fill"
        case .poseidon: return "drop.triangle.fill"
        case .corse: return "tortoise.fill"
        case .pulse: return "bolt.heart.fill"
        case .shield: return "shield.fill"
        case .council: return "building.columns.fill"
        }
    }
    
    /// Kullanıcıya gösterilen isim — mitolojik kod adı yerine kavramsal başlık.
    /// 2026-04-30: rawValue'lar persistance / JSON için korunuyor; UI bu alanı okur.
    var displayName: String {
        switch self {
        case .argus:    return "Argus"
        case .aether:   return "Makro Ortam"
        case .orion:    return "Teknik Analiz"
        case .demeter:  return "Sektör Rotasyonu"
        case .atlas:    return "Bilanço & Değerleme"
        case .hermes:   return "Haber Akışı"
        case .poseidon: return "Para Akışı"
        case .corse:    return "Pozisyon Takibi (Swing)"
        case .pulse:    return "Hızlı İşlem (Scalp)"
        case .shield:   return "Risk Kalkanı"
        case .council:  return "Karar Konseyi"
        }
    }

    var description: String {
        switch self {
        case .argus:
            return "Sistemin beyni. Teknik, bilanço, makro, haber ve sektör katmanlarından gelen sinyalleri birleştirir; uzun ve kısa vadeyi ayrı ayrı değerlendirir. Nihai çıktı: AL, SAT veya BEKLE."
        case .aether:
            return "Makro ortamı okur. VIX, faiz, DXY ve risk iştahı verilerini izler; piyasa rejimi savunmacıya kayıyorsa pozisyon büyüklüğünü ve risk dozunu küçültür. Yön değil, ölçek katmanıdır."
        case .orion:
            return "Teknik analiz katmanı. Trend, momentum, RSI ve MACD gibi göstergelerle fiyatın yönünü ve giriş zamanlamasını ölçer. Kısa-orta vadeli sinyalin tetikleyicisidir."
        case .demeter:
            return "Sektör rotasyonu. Sermaye akışının hangi sektöre geldiğini, hangisinden çıktığını analiz eder; rotasyondaki kazanan tarafa yönlendirir, zayıflayan sektörlerde temkinli durur."
        case .atlas:
            return "Bilanço ve değerleme katmanı. F/K, PD/DD, borç/özkaynak, kârlılık gibi metriklerle şirketin temel kalitesini ölçer; piyasa fiyatının bu kaliteyi ne kadar yansıttığını gösterir."
        case .hermes:
            return "Haber akışı katmanı. Haberlerin tonunu (pozitif / negatif / nötr) sınıflandırır, kaynak güvenilirliğini ağırlıklandırır, gürültüyü kalıcı bilgiden ayırır."
        case .poseidon:
            return "Para akışı katmanı. Kurumsal alıcı-satıcı dengesini ve büyük hacim hareketlerini izler; perakende kaynaklı geçici dalgalardan ayırır."
        case .corse:
            return "Uzun vadeli (swing) işlem profili. Pozisyonları günler veya haftalar boyunca taşır; trend takibi yapar, sık giriş-çıkış yapmaz."
        case .pulse:
            return "Kısa vadeli (scalp) işlem profili. Dakikalar veya saatler süren küçük hareketleri hedefler; hızlı giriş-çıkış disiplinine bağlıdır."
        case .shield:
            return "Portföy koruma katmanı. Stop-loss tetikleme, hedge önerisi ve risk limiti aşımı uyarısı yapar; sermayeyi korumak için devreye girer."
        case .council:
            return "Karar konseyi. Tüm analiz katmanlarının skorlarını toplar, ağırlıklandırır, çelişkileri çözer ve nihai AL / SAT / BEKLE kararını verir."
        }
    }
}
