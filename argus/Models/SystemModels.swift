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
    
    var description: String {
        switch self {
        case .argus:
            return "Sistemin beyni; Tüm verileri gören dev. Temel analiz, haber akışı ve makro verileri birleştirerek 'Ne almalı?' sorusuna yanıt arar. Asla uyumaz."
        case .aether:
            return "Piyasa Atmosferi; Makroekonomik iklimi (VIX, Faizler, DXY) koklar. Fırtına yaklaşıyorsa risk iştahını kapatır. 'Ne zaman almalı?' sorusunun cevabıdır."
        case .orion:
            return "Avcı; Teknik analizin ustasıdır. Trendleri, formasyonları ve momentumu hesaplar. Fiyatın 'Nereden alınmalı?' olduğunu belirler. Keskin nişancıdır."
        case .demeter:
            return "Doğa Ana; Sektörel döngüleri ve sermaye rotasyonunu yönetir. Paranın hangi tarlada (sektörde) yeşerdiğini, hangisinde kuruduğunu söyler. Verim odaklıdır."
        case .atlas:
            return "Değerleme Uzmanı; Şirketlerin bilançolarını, nakit akışlarını ve adil değerini hesaplar. Fiyat etiketinin ötesindeki gerçek değeri bulur."
        case .hermes:
            return "Haberci; Sosyal medya, kap bildirimleri ve flaş haberleri ışık hızında tarar. Fiyat hareketinden önce bilgiyi size ulaştırır."
        case .poseidon:
            return "Balina Dedektifi; Derin sulardaki büyük oyuncuların (kurumsal fonlar, balinalar) hareketlerini izler. Büyük para nereye akarsa oraya yönelir."
        case .corse:
            return "Dayanıklılık Motoru (Swing); Sakin ve sabırlı. Pozisyonları günler/haftalar boyunca taşır. Trend takibi yapar. Stres seviyesi düşüktür."
        case .pulse:
            return "Nabız Motoru (Scalp); Yüksek adrenalin. Dakikalar hatta saniyeler süren işlemleri hedefler. Küçük fiyat hareketlerinden kar çıkarmaya çalışır."
        case .shield:
            return "Kalkan; Portföyü koruyan savunma mekanizması. İşler ters giderse devreye girer, stop-loss çalıştırır veya hedge pozisyonu açar."
        case .council:
            return "Konsey (Agora); Karar Merkezi. Tüm tanrıların (modüllerin) oylarını toplar, çelişkileri çözer ve nihai AL/SAT kararını verir. Demokrasi ile yönetilen yapay zeka."
        }
    }
}
