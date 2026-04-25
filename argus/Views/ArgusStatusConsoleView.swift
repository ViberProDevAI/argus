import SwiftUI

// MARK: - Argus Durum Panosu
//
// Kullanıcının "Ayarlar çok karmaşık değil mi?" notunun cevabı.
// Canlı durum + teşhis + modül sağlığı ayarlardan ayrıldı, tek sheet'te toplandı.
// Ayarlar sekmesi sadece AYAR (toggle/picker/link) için kullanılır.
//
// Bu view:
//   • Otopilot Harmony (mod + çarpan + human summary + diagnostic rows + blocker)
//   • Aether Rejim Radarı (banner + crossing + pulse + evidence)
//   • Modüller · Durum (9 motor sağlık listesi)

struct ArgusStatusConsoleView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var autoPilotStore = AutoPilotStore.shared
    @ObservedObject private var marketContext = MarketContextCoordinator.shared

    // Canlı değerler — parent view'dan push ediliyor (tek kaynak: SettingsView.refreshSnapshots)
    let aetherCurrent: Double
    let aetherVelocity: Double
    let aetherSignal: String
    let aetherCrossingMsg: String?
    let regimeDirection: String
    let regimeSummary: String?
    let regimeEvidence: [String]
    let regimeConfidence: Double
    let pulseSummary: String
    let pulseIntensity: String
    let pulseDirection: String
    let chironTradeCount: Int
    let chironWinRate: Int
    let alkindusPendingCount: Int
    let policyMode: String
    let marketOpenGlobal: Bool
    let marketOpenBist: Bool
    let watchlistCount: Int
    let tradeBlockReasons: [String]

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack(spacing: 16) {
                        autoPilotSection
                        lastScanSection
                        aetherRegimeSection
                        moduleHealthSection
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Durum Panosu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Otopilot bölümü

    private var autoPilotSection: some View {
        TerminalSection(title: "OTOPİLOT · TİCARET DURUMU") {
            // Ana toggle
            HStack(spacing: 12) {
                Image(systemName: autoPilotStore.isAutoPilotEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(autoPilotStore.isAutoPilotEnabled ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Otopilot")
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(autoPilotStore.isAutoPilotEnabled ? "Aktif — sinyaller takip ediliyor" : "Kapalı — hiçbir alım/satım yapılmaz")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $autoPilotStore.isAutoPilotEnabled)
                    .labelsHidden()
                    .tint(InstitutionalTheme.Colors.positive)
            }
            .padding(.vertical, 8)

            Divider().background(InstitutionalTheme.Colors.borderSubtle)

            // HARMONY paneli
            harmonyPanel

            Divider().background(InstitutionalTheme.Colors.borderSubtle)

            // Diagnostic satırları
            VStack(spacing: 6) {
                diagnosticRow(
                    label: "Risk politikası",
                    value: policyMode,
                    ok: policyMode == "NORMAL",
                    warnDetail: "makro risk-off · yeni alım kısıtlı"
                )
                diagnosticRow(
                    label: "Global piyasa",
                    value: marketOpenGlobal ? "Açık" : "Kapalı",
                    ok: marketOpenGlobal
                )
                diagnosticRow(
                    label: "BIST",
                    value: marketOpenBist ? "Açık" : "Kapalı",
                    ok: marketOpenBist
                )
                diagnosticRow(
                    label: "İzleme listesi",
                    value: "\(watchlistCount) sembol",
                    ok: watchlistCount > 0,
                    warnDetail: "liste boş — tarayacak bir şey yok"
                )
            }
            .padding(.vertical, 6)

            // Blocker özeti
            if !tradeBlockReasons.isEmpty {
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEDEN TRADE ETMİYOR")
                        .font(InstitutionalTheme.Typography.micro)
                        .tracking(1.5)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .padding(.top, 6)
                    ForEach(tradeBlockReasons, id: \.self) { reason in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(reason)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 16)
    }

    private var harmonyPanel: some View {
        let snap = marketContext.snapshot
        let (modeLabel, modeColor, modeIcon): (String, Color, String) = {
            if snap.opportunityMode {
                return ("FIRSAT MODU", InstitutionalTheme.Colors.positive, "bolt.fill")
            }
            if snap.protectiveMode {
                return ("KORUYUCU MOD", InstitutionalTheme.Colors.negative, "shield.lefthalf.filled")
            }
            return ("NORMAL SEYİR", InstitutionalTheme.Colors.primary, "gauge.medium")
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: modeIcon)
                    .font(.system(size: 14))
                    .foregroundColor(modeColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(modeLabel)
                            .font(InstitutionalTheme.Typography.caption)
                            .tracking(1.2)
                            .foregroundColor(modeColor)
                        Text("×\(String(format: "%.2f", snap.positionMultiplier))")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Text(snap.humanSummary)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack(spacing: 14) {
                miniStat(
                    label: "Rejim",
                    value: snap.regimeDirection == "STABLE" ? "stabil" : snap.regimeDirection == "RISING" ? "↑ %\(Int(snap.regimeConfidence * 100))" : "↓ %\(Int(snap.regimeConfidence * 100))",
                    color: snap.regimeDirection == "RISING" ? InstitutionalTheme.Colors.positive : (snap.regimeDirection == "FALLING" ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textSecondary)
                )
                miniStat(label: "Nabız", value: snap.pulseIntensity, color: pulseMiniColor(snap: snap))
                miniStat(label: "Haber", value: "+\(snap.hermesPositive)/-\(snap.hermesNegative)", color: InstitutionalTheme.Colors.textPrimary)
            }
            .padding(.leading, 30)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Son Tarama bölümü
    //
    // "Trade etmiyor" sorusunun en derin cevabı burada. Otopilot aktif + kapılar açık +
    // sembol bol olduğu halde sıfır alım varsa, sebep SİNYAL ÜRETİMİ veya SKIP aşamasında.
    // Bu bölüm AutoPilotStore.lastScanSummary'yi okuyup "X sembol tarandı, Y sinyal çıktı,
    // Z atlandı, en sık sebep: ..." detayını gösterir.

    private var lastScanSection: some View {
        TerminalSection(title: "SON TARAMA") {
            let summary = autoPilotStore.lastScanSummary

            if !summary.hasRun {
                // Otopilot loop henüz bir tur tamamlamamış — ilk iterasyon bekleniyor
                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("İlk tarama bekleniyor")
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("Otopilot henüz bir tur çalıştırmadı — 60 saniyeye kadar sürebilir")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                // Tarama özeti
                HStack(spacing: 10) {
                    Image(systemName: summary.signalCount > 0 ? "bolt.horizontal.fill" : "bolt.horizontal")
                        .font(.system(size: 14))
                        .foregroundColor(summary.signalCount > 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.textSecondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(summary.scannedCount) sembol tarandı")
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("\(ageText(summary.ageSeconds)) · \(summary.signalCount) sinyal · \(summary.skippedCount) atlandı")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)

                // Bakiye + pozisyon
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                HStack(spacing: 16) {
                    balanceCell(label: "Global", value: "$\(String(format: "%.0f", summary.globalBalance))", ok: summary.globalBalance > 100)
                    balanceCell(label: "BIST", value: "₺\(String(format: "%.0f", summary.bistBalance))", ok: summary.bistBalance > 100)
                    balanceCell(label: "Açık poz.", value: "\(summary.openPositions)", ok: true)
                }
                .padding(.vertical, 8)

                // En sık skip sebepleri
                if !summary.topSkipReasons.isEmpty {
                    Divider().background(InstitutionalTheme.Colors.borderSubtle)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EN SIK ATLAMA SEBEPLERİ")
                            .font(InstitutionalTheme.Typography.micro)
                            .tracking(1.5)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .padding(.top, 6)
                        ForEach(summary.topSkipReasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(.orange.opacity(0.8))
                                Text(reason)
                                    .font(InstitutionalTheme.Typography.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Sinyal yoksa özel uyarı
                if summary.signalCount == 0 && summary.skippedCount == 0 {
                    Divider().background(InstitutionalTheme.Colors.borderSubtle)
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("Tarama çalıştı ama ne sinyal üretildi ne atlama kaydedildi — Council eşikleri veya veri akışı kontrol edilmeli.")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func balanceCell(label: String, value: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(ok ? InstitutionalTheme.Colors.textPrimary : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ageText(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s) sn önce" }
        if s < 3600 { return "\(s / 60) dk önce" }
        return "\(s / 3600) sa önce"
    }

    // MARK: - Aether Rejim Radarı bölümü

    private var aetherRegimeSection: some View {
        TerminalSection(title: "AETHER · REJİM RADARI") {
            // Banner (sadece dönüşüm varsa)
            if regimeDirection == "RISING" {
                regimeBanner(
                    title: "REJİM DÖNÜŞÜMÜ — YUKARI",
                    summary: regimeSummary ?? "Korku geri çekiliyor",
                    evidence: regimeEvidence,
                    color: InstitutionalTheme.Colors.positive,
                    icon: "arrow.up.forward.app.fill"
                )
            } else if regimeDirection == "FALLING" {
                regimeBanner(
                    title: "REJİM BOZULMASI — AŞAĞI",
                    summary: regimeSummary ?? "Korku yayılıyor",
                    evidence: regimeEvidence,
                    color: InstitutionalTheme.Colors.negative,
                    icon: "arrow.down.forward.app.fill"
                )
            }

            // Canlı skor
            HStack(spacing: 12) {
                Image(systemName: signalSymbol)
                    .font(.system(size: 14))
                    .foregroundColor(signalColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skor: \(Int(aetherCurrent)) · Hız: \(String(format: "%+.1f", aetherVelocity))/gün")
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(aetherSignal)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(signalColor.opacity(0.9))
                }
                Spacer()
            }
            .padding(.vertical, 10)

            if let cross = aetherCrossingMsg {
                HStack {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.positive)
                    Text(cross)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            Divider().background(InstitutionalTheme.Colors.borderSubtle)

            // Nabız
            HStack(spacing: 10) {
                Image(systemName: pulseIcon)
                    .font(.system(size: 14))
                    .foregroundColor(pulseColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NABIZ")
                        .font(InstitutionalTheme.Typography.micro)
                        .tracking(1)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(pulseSummary)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Modül sağlık bölümü

    private var moduleHealthSection: some View {
        TerminalSection(title: "MODÜLLER · DURUM") {
            VStack(spacing: 0) {
                moduleRow(name: "Orion",      role: "Teknik",      active: true,  detail: "RSI/MACD + rejim-aware")
                moduleRow(name: "Atlas",      role: "Temel",       active: true,  detail: "Finansal oranlar + sektör")
                moduleRow(name: "Aether",     role: "Makro",       active: true,  detail: aetherModuleDetail)
                moduleRow(name: "Hermes",     role: "Haber",       degraded: true, detail: "Fallback: cached event aktif")
                moduleRow(name: "Prometheus", role: "Tahmin",      active: true,  detail: "5-gün Holt-Winters · advisor")
                moduleRow(name: "Demeter",    role: "Şok/Sektör",  active: true,  detail: "Advisor katmanı")
                moduleRow(name: "Athena",     role: "Faktör",      active: true,  detail: "Value/Quality/Momentum/Size/Risk")
                moduleRow(name: "Chiron",     role: "Öğrenme",     active: chironTradeCount > 0,
                          detail: chironTradeCount > 0 ? "WR %\(chironWinRate) · T \(chironTradeCount)" : "Veri birikiyor")
                moduleRow(name: "Alkindus",   role: "Kalibrasyon", active: alkindusPendingCount > 0,
                          detail: alkindusPendingCount > 0 ? "\(alkindusPendingCount) gözlem bekliyor" : "Sıra boş",
                          isLast: true)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Yardımcı görsel bileşenler

    private func regimeBanner(title: String, summary: String, evidence: [String], color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(InstitutionalTheme.Typography.caption)
                        .tracking(1.5)
                        .foregroundColor(color)
                    Text(summary)
                        .font(InstitutionalTheme.Typography.body)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("%\(Int(regimeConfidence * 100))")
                    .font(InstitutionalTheme.Typography.body)
                    .foregroundColor(color)
            }

            if !evidence.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(evidence, id: \.self) { e in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(color.opacity(0.8))
                            Text(e)
                                .font(InstitutionalTheme.Typography.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 0.5)
        )
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func diagnosticRow(label: String, value: String, ok: Bool, warnDetail: String? = nil) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ok ? InstitutionalTheme.Colors.positive : .orange)
                .frame(width: 6, height: 6)
            Text(label)
                .font(InstitutionalTheme.Typography.body)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(InstitutionalTheme.Typography.body)
                    .foregroundColor(ok ? InstitutionalTheme.Colors.positive : .orange)
                if let d = ok ? nil : warnDetail {
                    Text(d)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(color)
        }
    }

    private func moduleRow(name: String, role: String, active: Bool = false, degraded: Bool = false, detail: String, isLast: Bool = false) -> some View {
        let statusColor: Color = degraded ? .orange : (active ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.textSecondary)
        let statusLabel = degraded ? "AZALTILMIŞ" : (active ? "AKTİF" : "BEKLEME")

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(InstitutionalTheme.Typography.body)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(role)
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Text(detail)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(statusLabel)
                    .font(InstitutionalTheme.Typography.micro)
                    .tracking(1)
                    .foregroundColor(statusColor)
            }
            .padding(.vertical, 10)
            if !isLast {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle.opacity(0.4))
                    .frame(height: 0.5)
            }
        }
    }

    private var signalSymbol: String {
        switch aetherSignal {
        case let s where s.contains("RECOVERING_FAST"):    return "arrow.up.forward.app.fill"
        case let s where s.contains("RECOVERING"):         return "arrow.up.right.circle.fill"
        case let s where s.contains("DETERIORATING_FAST"): return "arrow.down.forward.app.fill"
        case let s where s.contains("DETERIORATING"):      return "arrow.down.right.circle.fill"
        default:                                            return "minus.circle.fill"
        }
    }

    private var signalColor: Color {
        switch aetherSignal {
        case let s where s.contains("RECOVERING"):    return InstitutionalTheme.Colors.positive
        case let s where s.contains("DETERIORATING"): return InstitutionalTheme.Colors.negative
        default:                                       return InstitutionalTheme.Colors.textSecondary
        }
    }

    private var pulseIcon: String {
        switch pulseIntensity {
        case "EXTREME":  return pulseDirection == "UP" ? "bolt.fill" : "bolt.trianglebadge.exclamationmark.fill"
        case "SURGING":  return pulseDirection == "UP" ? "arrow.up.forward.app.fill" : "arrow.down.forward.app.fill"
        case "STIRRING": return "waveform.path.ecg"
        case "NORMAL":   return "waveform"
        default:         return "moon.zzz.fill"
        }
    }

    private var pulseColor: Color {
        switch pulseIntensity {
        case "EXTREME", "SURGING":
            return pulseDirection == "UP" ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
        case "STIRRING": return .orange
        case "NORMAL":   return InstitutionalTheme.Colors.primary
        default:         return InstitutionalTheme.Colors.textSecondary
        }
    }

    private func pulseMiniColor(snap: MarketContextCoordinator.Snapshot) -> Color {
        switch snap.pulseIntensity {
        case "EXTREME", "SURGING":
            return snap.pulseDirection == "UP" ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
        case "STIRRING":
            return .orange
        default:
            return InstitutionalTheme.Colors.textSecondary
        }
    }

    private var aetherModuleDetail: String {
        guard aetherCurrent > 0 else { return "Veri bekleniyor" }
        return "Skor \(Int(aetherCurrent)) · \(String(format: "%+.1f", aetherVelocity))/gün"
    }
}
