import SwiftUI

// MARK: - ExpectationsEntryView (Yaklaşan veriler)
//
// 2026-05-04 H-63 — komple yeniden yazıldı.
// Eski yapı: sarı bulb hint + mor takvim listesi + cyan input row + orange
// surprises + blue link kartlar (V5 tinted dilinde, emoji yağmuru).
// Yeni yapı: sade iOS list. Her gösterge tek satır → tıklayınca
// IndicatorExpectationFormView push ediliyor (üstünde Kaydet, altında
// büyük input + sade meta + geçmiş açıklamalar).

struct ExpectationsEntryView: View {
    @ObservedObject private var store = ExpectationsStore.shared
    @Environment(\.dismiss) private var dismiss
    // 2026-05-09: Drawer'dan açılan view nested NavigationLink chain'inde
    // pop'lanırken `\.dismiss` zaman zaman ölü kalıyor; eski API fallback.
    @Environment(\.presentationMode) private var presentationMode

    private func popBack() {
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topNav

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        introParagraph
                        indicatorList
                        footerNote
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Üst nav

    private var topNav: some View {
        HStack(spacing: 8) {
            Button(action: popBack) {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Fonts.custom(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")

            Text("Yaklaşan veriler")
                .font(DesignTokens.Fonts.custom(size: 17, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    // MARK: - Giriş paragrafı

    private var introParagraph: some View {
        Text("Veri açıklanmadan önce beklediğin değeri kaydet. Sonra gerçekleşen değerle karşılaştırılır.")
            .font(DesignTokens.Fonts.custom(size: 13))
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 22)
    }

    // MARK: - Gösterge listesi

    private var indicatorList: some View {
        VStack(spacing: 0) {
            let indicators = ExpectationsStore.EconomicIndicator.allCases
            ForEach(Array(indicators.enumerated()), id: \.offset) { idx, indicator in
                NavigationLink(destination: IndicatorExpectationFormView(indicator: indicator)) {
                    indicatorRow(indicator)
                }
                .buttonStyle(.plain)
                if idx < indicators.count - 1 {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.borderSubtle)
                        .frame(height: 0.5)
                        .padding(.leading, 14)
                }
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 14)
    }

    private func indicatorRow(_ indicator: ExpectationsStore.EconomicIndicator) -> some View {
        let entry = store.getExpectation(for: indicator)
        let isPending = entry != nil && entry?.actualValue == nil
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(indicator.shortName)
                    .font(DesignTokens.Fonts.custom(size: 15))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(indicator.scheduleHint)
                    .font(DesignTokens.Fonts.custom(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Spacer()
            if let entry, isPending {
                Text(String(format: "%.1f%@", entry.expectedValue, indicator.unit))
                    .font(DesignTokens.Fonts.custom(size: 14, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(DesignTokens.Fonts.custom(size: 14))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(DesignTokens.Fonts.custom(size: 12, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // MARK: - Footer

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Veriler genellikle 15:30 ya da 16:00 TSİ'de açıklanır. Beklentinden saparsa Makro skoruna ±10 puan etki eder.")
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - IndicatorExpectationFormView (Tek release form)
//
// Tek gösterge için tahmin girişi. Üst nav'da Kaydet (mavi accent),
// liste dilinde input alanı + Sil (kırmızı satır) + geçmiş açıklamalar.
// Klavye otomatik açılır.

struct IndicatorExpectationFormView: View {
    let indicator: ExpectationsStore.EconomicIndicator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var store = ExpectationsStore.shared
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool

    private func popBack() {
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topNav

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        metaParagraph
                        inputGroup
                        if existing != nil {
                            deleteRow
                        }
                        if !pastReleases.isEmpty {
                            historyGroup
                        }
                        footerNote
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Mevcut tahmin varsa input'a yükle.
            if let entry = existing, entry.actualValue == nil {
                inputText = String(format: "%.2f", entry.expectedValue)
            }
            // Klavyeyi otomatik aç.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                inputFocused = true
            }
        }
    }

    // MARK: - Üst nav

    private var topNav: some View {
        HStack(spacing: 8) {
            Button(action: popBack) {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Fonts.custom(size: 18, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")

            Text(indicator.shortName)
                .font(DesignTokens.Fonts.custom(size: 17, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: save) {
                Text("Kaydet")
                    .font(DesignTokens.Fonts.custom(size: 15, weight: .medium))
                    .foregroundColor(canSave ? InstitutionalTheme.Colors.holo : InstitutionalTheme.Colors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)
        }
    }

    private var canSave: Bool {
        let cleaned = inputText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) != nil
    }

    // MARK: - Meta paragraf

    private var metaParagraph: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(indicator.fullDisplayName)
                .font(DesignTokens.Fonts.custom(size: 14))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(indicator.scheduleHint)
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Input grubu

    private var inputGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tahminim")
                .font(DesignTokens.Fonts.custom(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.leading, 2)

            HStack(spacing: 0) {
                Text("Beklenen değer")
                    .font(DesignTokens.Fonts.custom(size: 15))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                TextField(indicator.placeholder, text: $inputText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(DesignTokens.Fonts.custom(size: 15, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 80)
                    .focused($inputFocused)
                Text(indicator.unit)
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.bottom, existing == nil ? 22 : 12)
    }

    // MARK: - Sil satırı

    private var deleteRow: some View {
        Button(action: deleteExpectation) {
            HStack {
                Text("Sil")
                    .font(DesignTokens.Fonts.custom(size: 15))
                    .foregroundColor(InstitutionalTheme.Colors.crimson)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
    }

    // MARK: - Geçmiş açıklamalar

    private var pastReleases: [PastRelease] {
        // Bu göstergeye ait actualValue dolu kayıtları en yeniden eskiye sırala.
        store.expectations.values
            .filter { $0.indicator == indicator && $0.actualValue != nil }
            .sorted { ($0.announcedAt ?? .distantPast) > ($1.announcedAt ?? .distantPast) }
            .prefix(5)
            .map { entry in
                PastRelease(
                    when: entry.announcedAt ?? entry.enteredAt,
                    actual: entry.actualValue ?? 0
                )
            }
    }

    private struct PastRelease {
        let when: Date
        let actual: Double
    }

    private var historyGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Geçmiş açıklamalar")
                .font(DesignTokens.Fonts.custom(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(pastReleases.enumerated()), id: \.offset) { idx, item in
                    HStack {
                        Text(monthLabel(item.when))
                            .font(DesignTokens.Fonts.custom(size: 14))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f%@", item.actual, indicator.unit))
                            .font(DesignTokens.Fonts.custom(size: 14, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if idx < pastReleases.count - 1 {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, 14)
                    }
                }
            }
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.bottom, 14)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("\(indicator.helpText). Beklentin gerçekleşen değerle karşılaştırılır; sapma Makro skorunu etkiler.")
            .font(DesignTokens.Fonts.custom(size: 12))
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    // MARK: - Aksiyonlar

    private var existing: ExpectationsStore.ExpectationEntry? {
        store.getExpectation(for: indicator)
    }

    private func save() {
        let cleaned = inputText
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return }

        if existing?.actualValue == nil, existing != nil {
            store.updateExpectedValue(indicator: indicator, newValue: value)
        } else {
            store.setExpectation(indicator: indicator, value: value)
        }

        let h = UIImpactFeedbackGenerator(style: .medium)
        h.impactOccurred()

        inputFocused = false
        dismiss()
    }

    private func deleteExpectation() {
        store.clearExpectation(for: indicator)
        let h = UIImpactFeedbackGenerator(style: .light)
        h.impactOccurred()
        dismiss()
    }
}

// MARK: - Indicator helpers

extension ExpectationsStore.EconomicIndicator {
    /// Form ekranında gösterilen uzun isim. displayName parantez içeriyor;
    /// burada plain Türkçe açıklamayı bırakıyoruz.
    var fullDisplayName: String {
        switch self {
        case .cpi: return "Tüketici fiyat endeksi, yıllık değişim"
        case .unemployment: return "İşsizlik oranı (U-3)"
        case .payrolls: return "Tarım dışı istihdam, aylık değişim"
        case .claims: return "Haftalık işsizlik başvurusu"
        case .pce: return "Çekirdek PCE enflasyonu, yıllık"
        case .gdp: return "GSYİH, çeyreklik büyüme"
        }
    }

    /// Liste satırında ve formda göstergenin ne zaman açıklandığını
    /// anlatan kısa ifade.
    var scheduleHint: String {
        switch self {
        case .cpi: return "Her ayın 10–14'ü arası"
        case .payrolls: return "Her ayın ilk Cuma'sı"
        case .unemployment: return "İstihdam ile birlikte"
        case .claims: return "Her Perşembe 15:30 TSİ"
        case .pce: return "Her ayın son haftası"
        case .gdp: return "Çeyreklik · Oca / Nis / Tem / Eki"
        }
    }
}
