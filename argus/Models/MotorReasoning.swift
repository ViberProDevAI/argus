import Foundation

// MARK: - Motor Reasoning Helper
//
// 2026-04-25 H-34 — Sanctum'un her motor için "neden bu skoru verdi?"
// gerekçesini üretir. Tek source-of-truth: bu dosya. UI burada üretilen
// ikiliyi (`stance` + `summary`) okur, kendi metni üretmez.
//
// Stratejiler:
//   • Skor (0-100) → stance enum (al / sat / bekle / nötr)
//   • Skor + opsiyonel sub-detail → 1 cümlelik özet
//   • Sub-detail nil ise: skor band'ına göre genel bir özet üretilir,
//     "Veri bekleniyor" gibi boş kart hiç gösterilmez. Skoru olan motor
//     hep gerekçe üretir; skoru da yoksa motor tamamen gizlenir
//     (`isVisible == false`).
//
// Bu katman üzerine ileride Gemini destekli rich text eklemek mümkün —
// `MotorReasoning.shared.enrich(with: explanation)` gibi bir hook
// koyduğumuzda template metni Gemini varyantı ile değiştirilebilir.

enum MotorStance: String, Sendable {
    case strongBuy = "Topla"
    case buy = "Al"
    case wait = "Bekle"
    case neutral = "Nötr"
    case sell = "Sat"
    case strongSell = "Boşalt"

    /// Skor → stance eşleşmesi. Her motor aynı eşikleri kullanır,
    /// böylece kart formatı tutarlı kalır.
    static func from(score: Double) -> MotorStance {
        switch score {
        case 80...:   return .strongBuy
        case 60..<80: return .buy
        case 45..<60: return .wait
        case 35..<45: return .neutral
        case 20..<35: return .sell
        default:      return .strongSell
        }
    }

    /// UI rengi — tema token'ları üzerinden.
    var arrowGlyph: String {
        switch self {
        case .strongBuy, .buy:   return "↑"
        case .wait, .neutral:    return "→"
        case .sell, .strongSell: return "↓"
        }
    }
}

/// Bir motorun Sanctum kartında gösterilecek tüm bilgisi.
struct MotorReasoning {
    let motor: MotorEngine
    let score: Double
    let stance: MotorStance
    let summary: String      // 1 cümlelik gerekçe (her zaman dolu)
    let weight: Double?      // Konsey ağırlığı 0-1, yoksa nil
    let isVisible: Bool      // Skoru hiç yoksa false → kart gizlenir

    static func empty(for motor: MotorEngine) -> MotorReasoning {
        MotorReasoning(
            motor: motor,
            score: 0,
            stance: .neutral,
            summary: "",
            weight: nil,
            isVisible: false
        )
    }

    /// Motor enum'da var ve user-facing, ama veri henüz hazır değil.
    /// Kart "Bekleniyor" durumunda görünür, score 0 (UI'da "—" yazılır).
    /// 2026-04-25 H-37: Daha önce "skor 0 → motor gizli" davranışı vardı,
    /// makro/temel dışındaki motorlar gözükmüyordu. Şimdi her zaman
    /// listede yer alır, sadece içeriği "Bekleniyor".
    static func pending(motor: MotorEngine, weight: Double?) -> MotorReasoning {
        MotorReasoning(
            motor: motor,
            score: 0,
            stance: .neutral,
            summary: "Veri bekleniyor",
            weight: weight,
            isVisible: true
        )
    }
}

// MARK: - Köprü Compute Properties (Geçici)
//
// `MotorReasoning` extension'ı motor skorlarına ve Chiron sonucuna doğrudan
// erişiyor; ancak `ArgusGrandDecision` struct'ında bu skorlar **Decision**
// tipleri içinde (`netSupport`) saklanıyor. Burası iki dünya arasındaki
// köprü. Demeter ve Chiron için struct'a henüz alan eklenmediğinden boş
// dönüyor → ilgili kartlar `score == 0` veya `nil` koşuluyla gizleniyor.
extension ArgusGrandDecision {
    var orionScore: Double { orionDecision.netSupport * 100 }
    var atlasScore: Double { (atlasDecision?.netSupport ?? 0) * 100 }
    var aetherScore: Double { aetherDecision.netSupport * 100 }
    var hermesScore: Double { (hermesDecision?.netSupport ?? 0) * 100 }
    var demeterScore: Double { 0 }
    var chironResult: ChironResult? { nil }

    /// Sanctum başlığı için "konsey skoru" — şu an `confidence` üzerinden okuyoruz.
    /// Yarım kalan iş tamamlandığında (skor + güven ayrımı yapıldığında) bu
    /// köprü silinir, gerçek skor alanı kullanılır.
    var finalScoreCore: Double { confidence }

    /// `ArgusAction` (5'li koleksiyon) → `SignalAction` (UI'nın beklediği 5'li
    /// koleksiyon). `neutral` ekrana "Bekle" kelimesiyle düştüğü için `.hold`
    /// olarak eşliyoruz. Tüm `ArgusAction` case'leri kapsandığı için non-optional;
    /// optional kullanım yerleri (`decision?.finalActionCore`) chain üzerinden
    /// otomatik optional olur.
    var finalActionCore: SignalAction {
        switch action {
        case .aggressiveBuy, .accumulate: return .buy
        case .neutral:                    return .hold
        case .trim, .liquidate:           return .sell
        }
    }
}

// MARK: - ArgusGrandDecision → 7 motor reasoning

extension ArgusGrandDecision {

    /// Bu hisse için tüm user-facing motorların gerekçeleri.
    /// Sırayla: Teknik, Bilanço, Makro, Haber, Tahmin, Sektör, Rejim.
    /// 2026-04-25 H-37: Motor "veri yok" durumunda da listede kalır,
    /// "Bekleniyor" özet metni ile gözükür. Eski isVisible filtresi
    /// "skor 0 → motor gizli" davranışı yaratıyordu, makro/temel dışı
    /// her şey kayboluyordu. Yalnızca motor enum'da `isUserFacing == false`
    /// olanlar (Athena, Phoenix, rezerv motorlar) gizli.
    var motorReasonings: [MotorReasoning] {
        [
            reasoningOrion(),
            reasoningAtlas(),
            reasoningAether(),
            reasoningHermes(),
            reasoningPrometheus(),
            reasoningDemeter(),
            reasoningChiron()
        ].filter { $0.motor.isUserFacing }
    }

    /// Konsey ağırlığını 0-1 olarak döndürür; `moduleWeights` yoksa
    /// görünür motor sayısına eşit dağıtılır (1/N).
    /// `InformationWeights` subscript desteklemediği için switch ile eşleşiyoruz.
    func weight(forKey key: String, fallbackCount: Int) -> Double? {
        let stored: Double? = {
            switch key {
            case "orion":  return moduleWeights?.orion
            case "atlas":  return moduleWeights?.atlas
            case "aether": return moduleWeights?.aether
            default:       return nil
            }
        }()
        if let w = stored { return w }
        guard fallbackCount > 0 else { return nil }
        return 1.0 / Double(fallbackCount)
    }

    // MARK: Motor-specific generators

    private func reasoningOrion() -> MotorReasoning {
        let score = orionScore
        if score <= 0 { return .pending(motor: .orion, weight: weight(forKey: "orion", fallbackCount: 7)) }
        let stance = MotorStance.from(score: score)
        let verdict = orionDetails?.verdict
        let summary: String = {
            if let v = verdict, !v.isEmpty {
                return "Teknik verdiği: \(v)"
            }
            switch stance {
            case .strongBuy:   return "Momentum güçlü, teknik resim olumlu"
            case .buy:         return "Trend yukarı, alım sinyali var"
            case .wait:        return "Kararsız, sinyal henüz net değil"
            case .neutral:     return "Yatay seyir, açık bir sinyal yok"
            case .sell:        return "Momentum zayıflıyor, dikkat"
            case .strongSell:  return "Teknik resim bozuk, satış baskısı"
            }
        }()
        return MotorReasoning(
            motor: .orion, score: score, stance: stance,
            summary: summary,
            weight: weight(forKey: "orion", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningAtlas() -> MotorReasoning {
        let score = atlasScore
        if score <= 0 { return .pending(motor: .atlas, weight: weight(forKey: "atlas", fallbackCount: 7)) }
        let stance = MotorStance.from(score: score)
        let summary: String = {
            switch stance {
            case .strongBuy:   return "Temeller çok güçlü, değerleme cazip"
            case .buy:         return "Bilanço sağlam, finansal yapı iyi"
            case .wait:        return "Temeller karışık, beklemek mantıklı"
            case .neutral:     return "Ortalama bilanço, belirgin avantaj yok"
            case .sell:        return "Temellerde zayıflık, dikkat"
            case .strongSell:  return "Bilanço bozuk, finansal risk yüksek"
            }
        }()
        return MotorReasoning(
            motor: .atlas, score: score, stance: stance,
            summary: summary,
            weight: weight(forKey: "atlas", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningAether() -> MotorReasoning {
        let score = aetherScore
        if score <= 0 { return .pending(motor: .aether, weight: weight(forKey: "aether", fallbackCount: 7)) }
        let stance = MotorStance.from(score: score)
        let summary: String = {
            switch stance {
            case .strongBuy:   return "Risk-on güçlü, makro destekleyici"
            case .buy:         return "Makro ortam olumlu, rüzgâr arkada"
            case .wait:        return "Makro karışık, net yön yok"
            case .neutral:     return "Dengeli ortam, makro etkisi sınırlı"
            case .sell:        return "Makro baskı var, dikkatli ol"
            case .strongSell:  return "Risk-off, makro çok zorlayıcı"
            }
        }()
        return MotorReasoning(
            motor: .aether, score: score, stance: stance,
            summary: summary,
            weight: weight(forKey: "aether", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningHermes() -> MotorReasoning {
        let score = hermesScore
        if score <= 0 { return .pending(motor: .hermes, weight: weight(forKey: "hermes", fallbackCount: 7)) }
        let stance = MotorStance.from(score: score)
        let summary: String = {
            switch stance {
            case .strongBuy:   return "Haber akışı çok olumlu, sentiment güçlü"
            case .buy:         return "Olumlu haberler var, hava iyi"
            case .wait:        return "Karışık haber akışı, etki belirsiz"
            case .neutral:     return "Sessiz dönem, kayda değer haber yok"
            case .sell:        return "Olumsuz haberler var, dikkat"
            case .strongSell:  return "Sert olumsuz haber akışı, baskı yüksek"
            }
        }()
        return MotorReasoning(
            motor: .hermes, score: score, stance: stance,
            summary: summary,
            weight: weight(forKey: "hermes", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningPrometheus() -> MotorReasoning {
        // Phoenix advice taşır (Prometheus reuse Phoenix asset/data).
        let w = weight(forKey: "prometheus", fallbackCount: 7)
        guard let phx = phoenixAdvice, phx.status == .active else {
            return .pending(motor: .prometheus, weight: w)
        }
        let slope = phx.regressionSlope ?? 0
        let confPct = phx.confidence  // 0-100
        let predictedPct = slope * 100

        let stance: MotorStance
        if confPct < 40 { stance = .wait }
        else if predictedPct >= 3 { stance = .buy }
        else if predictedPct >= 1 { stance = .wait }
        else if predictedPct <= -3 { stance = .sell }
        else if predictedPct <= -1 { stance = .neutral }
        else { stance = .neutral }

        // Phoenix kendi `reasonShort`'unu üretiyor — varsa onu kullan,
        // yoksa şablon ile yön + güven üret.
        let summary: String = {
            if !phx.reasonShort.isEmpty { return phx.reasonShort }
            let dirText: String
            if predictedPct >= 0.5 {
                dirText = String(format: "+%.1f%% yukarı", predictedPct)
            } else if predictedPct <= -0.5 {
                dirText = String(format: "%.1f%% aşağı", predictedPct)
            } else {
                dirText = "yatay"
            }
            return "Kanal tahmini \(dirText), güven %\(Int(confPct))"
        }()

        return MotorReasoning(
            motor: .prometheus,
            score: max(0, min(100, 50 + predictedPct * 5)),
            stance: stance,
            summary: summary,
            weight: weight(forKey: "prometheus", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningDemeter() -> MotorReasoning {
        let score = demeterScore
        if score <= 0 { return .pending(motor: .demeter, weight: weight(forKey: "demeter", fallbackCount: 7)) }
        let stance = MotorStance.from(score: score)
        let summary: String = {
            switch stance {
            case .strongBuy:   return "Sektör çok güçlü, rotasyonda lider"
            case .buy:         return "Sektör pozitif, hisse rotasyon avantajında"
            case .wait:        return "Sektör karışık, net üstünlük yok"
            case .neutral:     return "Sektör performansı ortalama"
            case .sell:        return "Sektör zayıf, dışarı kaçış var"
            case .strongSell:  return "Sektör çok zayıf, rotasyonda kaybeden"
            }
        }()
        return MotorReasoning(
            motor: .demeter, score: score, stance: stance,
            summary: summary,
            weight: weight(forKey: "demeter", fallbackCount: 7),
            isVisible: true
        )
    }

    private func reasoningChiron() -> MotorReasoning {
        let w = weight(forKey: "chiron", fallbackCount: 7)
        guard let chiron = chironResult else {
            return .pending(motor: .chiron, weight: w)
        }
        // Chiron skoru üretmiyor, rejim + iki açıklama metni üretiyor.
        // explanationBody varsa onu olduğu gibi kullan; yoksa şablon.
        let regime = chiron.regime
        let pseudoScore: Double
        let stance: MotorStance

        switch regime {
        case .trend:     pseudoScore = 75; stance = .buy
        case .chop:      pseudoScore = 50; stance = .wait
        case .riskOff:   pseudoScore = 30; stance = .sell
        case .newsShock: pseudoScore = 40; stance = .wait
        case .neutral:   pseudoScore = 50; stance = .neutral
        }

        let summary: String = {
            if !chiron.explanationBody.isEmpty { return chiron.explanationBody }
            switch regime {
            case .trend:     return "Trend rejimi aktif"
            case .chop:      return "Yatay seyir, dar bantta"
            case .riskOff:   return "Riskten kaçış, defansif"
            case .newsShock: return "Haber şoku, oynaklık yüksek"
            case .neutral:   return "Nötr rejim, net yön yok"
            }
        }()

        return MotorReasoning(
            motor: .chiron,
            score: pseudoScore,
            stance: stance,
            summary: summary,
            weight: weight(forKey: "chiron", fallbackCount: 7),
            isVisible: true
        )
    }
}

// MARK: - Conflict / Alliance Map

extension ArgusGrandDecision {

    /// "Teknik + Haber ittifakı, Makro itirazı dengelemiyor" tipi
    /// tek cümle. Skorları sıralar; en yüksek 2-3 motoru destekçi,
    /// en düşük 1-2 motoru itirazcı olarak adlandırır. Hepsi yakın
    /// skorlarsa "konsensüs" cümlesi döner.
    var conflictMapText: String {
        let reasonings = motorReasonings.filter { $0.score > 0 }
        guard reasonings.count >= 2 else {
            return "Yeterli motor verisi yok, konsensüs oluşmadı."
        }
        let sorted = reasonings.sorted { $0.score > $1.score }
        let top = sorted.prefix(3).filter { $0.score >= 60 }
        let bottom = sorted.suffix(2).filter { $0.score <= 40 }

        // Tüm skorlar 40-60 arasında ise konsensüs
        if top.isEmpty && bottom.isEmpty {
            return "Tüm motorlar kararsız bölgede, konsey net yön bulamıyor."
        }

        let topNames = top.map { $0.motor.displayName }.joined(separator: " + ")
        let bottomNames = bottom.map { $0.motor.displayName }.joined(separator: " + ")

        switch (top.isEmpty, bottom.isEmpty) {
        case (false, false):
            return "\(topNames) ittifakı pozitif, \(bottomNames) itirazı kararı dengeliyor."
        case (false, true):
            return "\(topNames) güçlü destek veriyor, kayda değer itiraz yok."
        case (true, false):
            return "\(bottomNames) baskısı kararı aşağı çekiyor, güçlü destekçi yok."
        case (true, true):
            return "Motorlar dağınık, net konsensüs oluşmuyor."
        }
    }
}
