import SwiftUI

/// V5 mockup "05 · Hisse Detayı" ekranının Swift karşılığı.
/// (`Argus_Mockup_V5.html` satır 1445-1619).
///
/// Layout sırası (V5 HTML ile aynı):
///   1. Navbar: back + sembol + aksiyon pill + bell + plus
///   2. Fiyat + değişim + son tarih
///   3. Chart + timeframe chipleri
///   4. Konsey kartı (aurora border + güven + kısa yorum)
///   5. Motor chip grid (Orion/Atlas/Aether/Hermes/Prometheus/Alkindus/Chiron/Demeter)
///   6. Temel veriler (P/E, EPS, MKT CAP, DIV, ROE, BETA)
///   7. Hermes mini feed (ilk 3 haber)
///   8. Sticky AL/BEKLE/SAT bar
///
/// Tüm değerler `viewModel`'dan canlı okunur. Nil/boş ise "—" gösterir,
/// hiçbir mock değer yok.
struct StockDetailV5Body: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode

    @Binding var selectedRange: String
    @Binding var showOrionSheet: Bool
    @Binding var showAtlasSheet: Bool
    @Binding var showAetherSheet: Bool
    @Binding var showHermesSheet: Bool
    @Binding var showAthenaSheet: Bool
    @Binding var showChironSheet: Bool
    @Binding var showPhoenixSheet: Bool
    @Binding var showSanctumSheet: Bool
    // 2026-04-23 Hotfix: motor chip binding'leri düzeltildi. Önceden
    // demeter→Athena, prometheus→Phoenix (Phoenix advice nil olduğunda
    // bomboş gri sheet), alkindus→Sanctum yönleniyordu. Her motor kendi
    // sheet'ini açsın diye 3 yeni binding eklendi.
    @Binding var showDemeterSheet: Bool
    @Binding var showPrometheusSheet: Bool
    @Binding var showAlkindusSheet: Bool

    // 2026-04-24 V5.H-11: Alkindus async öğrenme durumu.
    // `AlkindusSymbolLearner.getSymbolInsights(for:)` bir actor çağrısı
    // olduğu için view body'sinde senkron okunamaz — ekran açıldığında
    // `.task(id: symbol)` içinde bir kez çekilip @State'e düşer.
    // `alkindusInsightLoaded` henüz fetch bitmediğini ayırt etmek için;
    // nil insight ile "öğreniyor (5'ten az karar)" / "yükleniyor" ayrımı
    // ancak bu flag'le doğru söylenebilir.
    @State private var alkindusInsight: SymbolInsight?
    @State private var alkindusInsightLoaded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    navbar
                    priceBlock
                    chartBlock
                    councilCard
                    councilTraceCard
                    motorChipGrid
                    // 2026-04-22: "Temel Veriler" gridi kaldırıldı — veri
                    // sağlayıcılardan tutarlı karşılanamıyor. Temel analiz
                    // ihtiyacı için Atlas HoloPanel kullanılmalı.
                    hermesFeed
                    // Sticky bar altında yeterli boşluk
                    Color.clear.frame(height: 100)
                }
            }
            stickyActionBar
        }
        .navigationBarHidden(true)
        .task(id: symbol) {
            // Sembol değiştikçe Alkindus insight'ını yeniden çek. Eski
            // değeri hemen temizleyip `Loaded=false`'a düşürüyoruz ki
            // Alkindus chip'i "YÜKLENİYOR" durumuna geçsin — aksi halde
            // yeni sembol geldiğinde bir süre eski sembolün bilgisi
            // görünür (stale leak).
            alkindusInsight = nil
            alkindusInsightLoaded = false
            let insight = await AlkindusSymbolLearner.shared.getSymbolInsights(for: symbol)
            alkindusInsight = insight
            alkindusInsightLoaded = true
        }
    }

    // MARK: - 1. Navbar

    private var navbar: some View {
        HStack(spacing: 8) {
            // Back
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(InstitutionalTheme.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Sembol + pill + alt satır
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(symbol)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    if let action = councilAction {
                        ArgusPill(action.label, tone: action.tone)
                    }
                }
                Text(symbolSubtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Spacer()

            // Bell
            Button { /* notifications */ } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(InstitutionalTheme.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            // Plus (watchlist)
            Button {
                if WatchlistStore.shared.items.contains(symbol) {
                    WatchlistStore.shared.remove(symbol)
                } else {
                    _ = WatchlistStore.shared.add(symbol)
                }
            } label: {
                Image(systemName: inWatchlist ? "checkmark" : "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(InstitutionalTheme.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            InstitutionalTheme.Colors.surface1
                .overlay(ArgusHair().frame(maxHeight: .infinity, alignment: .bottom))
        )
    }

    // MARK: - 2. Fiyat

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                Text(currentPriceText)
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                if let change = priceChangeText {
                    Text(change.text)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(change.color)
                        .padding(.bottom, 6)
                }
            }
            Text(priceSubLine)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - 3. Chart

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            MiniLineChart(candles: filteredCandles, positive: isPriceUp)
                .frame(height: 140)
                .background(InstitutionalTheme.Colors.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))

            HStack(spacing: 6) {
                ForEach(["1G", "1H", "1A", "3A", "6A", "1Y", "5Y"], id: \.self) { tf in
                    Button {
                        selectedRange = tf
                    } label: {
                        ArgusChip(tf, tone: selectedRange == tf ? .holo : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - 4. Konsey Kartı

    private var councilCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(councilTintColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    MotorLogo(.council, size: 18)
                }
                Text("KONSEY KARARI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(councilTintColor)
                Spacer()
                if let d = decision {
                    ArgusChip("GÜVEN \(Int(d.confidence * 100))",
                              tone: tone(for: d.action))
                }
            }

            Text(councilSummary)
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let breakdown = councilBreakdown {
                HStack(spacing: 6) {
                    Text(breakdown.buy)
                        .foregroundColor(InstitutionalTheme.Colors.aurora)
                    Text("·").foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(breakdown.wait)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("·").foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(breakdown.sell)
                        .foregroundColor(InstitutionalTheme.Colors.crimson)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(councilTintColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .onTapGesture {
            showSanctumSheet = true
        }
    }

    // MARK: - 4.5 Karar Patikası — Konsey detayları (oylar / vetolar / danışmanlar)
    @ViewBuilder
    private var councilTraceCard: some View {
        if let d = decision {
            GrandCouncilDebateCard(decision: d)
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    // MARK: - 5. Motor chip grid (V5 05 — 8 motor, 4 sütun 2 satır)

    private var motorChipGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("MOTOR OYLARI · DOKUN")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                motorChip(.orion)      { showOrionSheet = true }
                motorChip(.atlas)      { showAtlasSheet = true }
                motorChip(.aether)     { showAetherSheet = true }
                motorChip(.hermes)     { showHermesSheet = true }
                // 2026-04-23 Hotfix: chip → doğru sheet.
                // Prometheus artık PrometheusPanelView'u, Alkindus
                // AlkindusDashboardView'u, Demeter kendi Demeter
                // panelini açıyor.
                motorChip(.prometheus) { showPrometheusSheet = true }
                motorChip(.alkindus)   { showAlkindusSheet = true }
                motorChip(.chiron)     { showChironSheet = true }
                motorChip(.demeter)    { showDemeterSheet = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // 2026-04-24 V5.H-11: Chip artık 3 durumda konuşur: active (veri var),
    // pending (hesaplanıyor/öğreniyor), empty (gerçekten boş — bu ekran için
    // henüz oluşmadı). Eski tek skor+bar ikilisi yerine `MotorChipState`
    // enum'u tek kaynaktan label/color/bar/opacity üretir.
    //
    // Motor logic sırası her motor için:
    //   1) Konsey kararı (grandDecision) dolu mu? — zengin label (aksiyon + skor)
    //   2) ArgusDecisionResult dolu mu? — ham skor ("POZ · 62")
    //   3) Motor'a özel zenginlik (Hermes news count, Chiron rejim, Alkindus insight)
    //   4) Hiçbiri yoksa pending — "HESAPLANIYOR / ÖĞRENİYOR / TARANIYOR"
    //
    // "—" kullanımı sadece gerçekten bu ekranda görünecek bir ikinci hat yoksa
    // (ör. Prometheus .error). Kullanıcı için "bilgisiz kart" bırakılmıyor.
    private enum MotorChipState {
        case active(label: String, score: Double?, color: Color)
        case pending(label: String)
        case empty(label: String)

        var label: String {
            switch self {
            case .active(let label, _, _), .pending(let label), .empty(let label): return label
            }
        }

        var barValue: Double? {
            if case let .active(_, score, _) = self { return score }
            return nil
        }

        var textColor: Color {
            switch self {
            case .active(_, _, let color): return color
            case .pending: return InstitutionalTheme.Colors.textSecondary
            case .empty: return InstitutionalTheme.Colors.textTertiary
            }
        }

        var borderOpacity: Double {
            switch self {
            case .active(_, let score, _): return score != nil ? 0.45 : 0.35
            case .pending: return 0.22
            case .empty: return 0.12
            }
        }

        var haloOpacity: Double {
            switch self {
            case .active(_, let score, _): return score != nil ? 0.35 : 0.25
            case .pending: return 0.18
            case .empty: return 0.10
            }
        }
    }

    private func motorChip(_ engine: MotorEngine, action: @escaping () -> Void) -> some View {
        let state = motorChipState(for: engine)
        let motorColor = InstitutionalTheme.Colors.Motors.color(for: engine)

        return Button(action: action) {
            VStack(spacing: 5) {
                // Sanctum orb ile aynı görsel ağırlık — motor glow halo
                ZStack {
                    Circle()
                        .fill(motorColor.opacity(state.haloOpacity))
                        .frame(width: 38, height: 38)
                        .blur(radius: 8)
                    Circle()
                        .fill(InstitutionalTheme.Colors.surface2)
                        .frame(width: 34, height: 34)
                    Circle()
                        .stroke(motorColor.opacity(state.borderOpacity + 0.2), lineWidth: 1)
                        .frame(width: 34, height: 34)
                    MotorLogo(engine, size: 22)
                }
                Text(engine.rawValue.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .tracking(0.5)
                Text(state.label)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(state.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let v = state.barValue {
                    ArgusBar(value: v, color: motorColor, height: 3)
                        .frame(width: 40)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(motorColor.opacity(state.borderOpacity), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. (Temel Veriler kaldırıldı 2026-04-22)
    //
    // Veri sağlayıcılardan P/E, EPS, MKT CAP, DIV, ROE, BETA için tutarlı
    // doluluk gelmiyor; kart boş hücrelerle bilgi kirliliği yaratıyordu.
    // Temel analiz için Atlas HoloPanel kullanılmalı — oradaki alt modeller
    // aynı verileri kendi sözleşmeleriyle besliyor.

    // MARK: - 7. Hermes feed

    private var hermesFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("HERMES · HABER \(hermesNewsCount > 0 ? "(\(hermesNewsCount))" : "")")

            if hermesItems.isEmpty {
                ArgusEmptyState(
                    icon: "newspaper",
                    title: "Haber bekleniyor",
                    message: "Bu sembol için henüz güncel Hermes verisi gelmedi."
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(hermesItems.prefix(3), id: \.id) { item in
                        newsCard(item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func newsCard(_ item: HermesNewsItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ArgusDot(color: item.tone.color, size: 6)
                Text(item.tone.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(item.tone.color)
                    .tracking(0.5)
                Text(item.source + " · " + item.ageText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
            Text(item.headline)
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    // MARK: - 8. Sticky Action Bar

    private var stickyActionBar: some View {
        HStack(spacing: 6) {
            stickyButton(title: "AL", tone: .aurora, glow: true) {
                viewModel.buy(symbol: symbol, quantity: 1)
            }
            stickyButton(title: "BEKLE", tone: .neutral, glow: false) {
                // no-op — bilgilendirme
            }
            stickyButton(title: "SAT", tone: .crimson, glow: false) {
                viewModel.sell(symbol: symbol, quantity: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(
            LinearGradient(
                colors: [Color.clear, InstitutionalTheme.Colors.backgroundDeep],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func stickyButton(title: String,
                              tone: ArgusChipTone,
                              glow: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(glow ? Color(hex: "0A1F0A") : tone.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glow ? tone.foreground : tone.foreground.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(tone.foreground.opacity(glow ? 0 : 0.45), lineWidth: 1)
                        )
                        .shadow(color: glow ? tone.foreground.opacity(0.35) : .clear,
                                radius: glow ? 14 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Veri türetmesi (canlı store'lardan)

    private var quote: Quote? {
        MarketDataStore.shared.getQuote(for: symbol) ?? viewModel.quotes[symbol]
    }

    private var currentPriceText: String {
        guard let q = quote, q.currentPrice > 0 else { return "—" }
        return String(format: isBist ? "₺%.2f" : "$%.2f", q.currentPrice)
    }

    private var priceChangeText: (text: String, color: Color)? {
        guard let q = quote, let prev = q.previousClose, prev > 0 else { return nil }
        let diff = q.currentPrice - prev
        let pct = (diff / prev) * 100
        let sign = diff >= 0 ? "+" : ""
        let text = "\(sign)\(String(format: isBist ? "₺%.2f" : "$%.2f", diff))  \(sign)\(String(format: "%.2f", pct))%"
        let color = diff >= 0 ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson
        return (text, color)
    }

    private var isPriceUp: Bool {
        guard let q = quote, let prev = q.previousClose else { return true }
        return q.currentPrice >= prev
    }

    private var priceSubLine: String {
        if quote != nil {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            let timeStr = df.string(from: Date())
            let suffix = isBist ? "BIST" : "EDT"
            return "SON · \(timeStr) \(suffix)"
        }
        return "SON · —"
    }

    private var isBist: Bool { symbol.uppercased().hasSuffix(".IS") }

    private var inWatchlist: Bool {
        WatchlistStore.shared.items.contains(symbol)
    }

    private var symbolSubtitle: String {
        let market = isBist ? "BIST · SİRKİYE" : "NASDAQ · GLOBAL"
        return market
    }

    // 2026-04-24 V5.H-11 (fix): Önceki getter `?? viewModel.argusDecisions[symbol].flatMap { _ in nil }`
    // yazılmıştı — bu her zaman nil döner (dead fallback). Sonuç: AutoPilot
    // scan sonrası `argusDecisions[symbol]` dolu ama `grandDecisions[symbol]`
    // henüz yokken Hermes/Atlas/Aether/Prometheus chip'leri boş ("—") kalıyordu.
    // Artık iki kaynak ayrı tutuluyor ve motorlar her iki kaynağı da dener.
    //
    // - `grandDecision`: Konsey final kararı. Yalnız konsey ajandası
    //   (councilAction, councilSummary, councilBreakdown) buradan okunur.
    // - `argusDecisionResult`: ArgusDecisionEngine (AutoPilot) çıktısı.
    //   Tekil motor skorları, Chiron rejim sonucu ve Phoenix advice burada.
    // - `decision` alias'ı yalnız eski kullanımları kırmamak için tutuluyor
    //   ve konsey kararını döndürür.
    private var grandDecision: ArgusGrandDecision? {
        SignalStateViewModel.shared.grandDecisions[symbol]
    }

    private var argusDecisionResult: ArgusDecisionResult? {
        viewModel.argusDecisions[symbol]
    }

    private var decision: ArgusGrandDecision? { grandDecision }

    private var councilAction: (label: String, tone: ArgusChipTone)? {
        guard let d = decision else { return nil }
        return (d.action.shortLabel, tone(for: d.action))
    }

    private var councilTintColor: Color {
        guard let d = decision else { return InstitutionalTheme.Colors.textSecondary }
        return tone(for: d.action).foreground
    }

    private func tone(for action: ArgusAction) -> ArgusChipTone {
        switch action {
        case .aggressiveBuy, .accumulate: return .aurora
        case .neutral:                     return .titan
        case .trim:                        return .custom(.orange)
        case .liquidate:                   return .crimson
        }
    }

    private var councilSummary: String {
        guard let d = decision else {
            return "Konsey kararı hazırlanıyor. Diğer modüller yüklenmesini bekliyor."
        }
        let base = d.reasoning.isEmpty ? d.action.rawValue : d.reasoning
        return base
    }

    /// Konsey oy sayımı — gerçek action'a göre filtreler. Eskiden modül adı
    /// "orion/atlas/aether/hermes" stringini içerip içermediğine bakıyordu;
    /// Aether SAT oyu verse bile "aether" geçtiği için AL sayılıyordu →
    /// kullanıcının ekranda "2 AL · 0 SAT" görüp "Konsey Kararsız" verdict
    /// almasının doğrudan sebebi bu yanlış sayımdı. Artık action-aware.
    /// Veto sayısı SAT'a eklenir (hard veto kesin satış sinyalidir).
    private var councilBreakdown: (buy: String, wait: String, sell: String)? {
        guard let d = decision else { return nil }
        let buyCount = d.contributors.filter { $0.action == .buy }.count
        let holdCount = d.contributors.filter { $0.action == .hold }.count
        let sellCount = d.contributors.filter { $0.action == .sell }.count + d.vetoes.count
        return (
            "\(buyCount) AL",
            "\(holdCount) BEKLE",
            "\(sellCount) SAT"
        )
    }

    // 2026-04-24 V5.H-11: Chip etiket üretimi MotorChipState enum'u üzerinden.
    // Her motor için 4 adımlı kaynak sıralaması:
    //   1) Konsey (grandDecision) → zengin aksiyon + skor
    //   2) ArgusDecisionResult → ham skor (POZ/NEG/NÖT · N)
    //   3) Motor'a özel zenginlik (Hermes haber sayısı, Chiron rejim,
    //      Alkindus insight, Prometheus direction)
    //   4) Hiçbiri yoksa pending — "HESAPLANIYOR / ÖĞRENİYOR / TARANIYOR"
    //
    // NOT: Phoenix / Prometheus aynı motor (tasarım isimleri farklı).
    // Prometheus chip'i `PhoenixAdvice`'ı okur.
    private func motorChipState(for engine: MotorEngine) -> MotorChipState {
        let dec = grandDecision
        let argus = argusDecisionResult
        let motorColor = InstitutionalTheme.Colors.Motors.color(for: engine)

        switch engine {
        case .orion:
            if let d = dec {
                let score = d.orionDetails?.score ?? (d.orionDecision.netSupport * 100)
                return .active(
                    label: formatScoreLabel(score, action: d.orionDecision.action),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.orionScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            return .pending(label: "HESAPLANIYOR")

        case .atlas:
            if let a = dec?.atlasDecision {
                let score = a.netSupport * 100
                return .active(
                    label: formatScoreLabel(score, action: a.action),
                    score: clamp01(a.netSupport),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.atlasScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            return .pending(label: "BİLANÇO OKUNUYOR")

        case .aether:
            if let ae = dec?.aetherDecision {
                let score = ae.netSupport * 100
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(ae.netSupport),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.aetherScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            return .pending(label: "MAKRO OKUNUYOR")

        case .hermes:
            if let h = dec?.hermesDecision {
                let score = h.netSupport * 100
                return .active(
                    label: formatScoreLabel(score, action: h.actionBias),
                    score: clamp01(h.netSupport),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.hermesScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            // Konsey/Argus kararı yoksa bile HermesNewsViewModel'den ham
            // haber gelmiş olabilir. Chip "N HABER" diyerek bilgi hattını açar.
            if hermesNewsCount > 0 {
                return .active(
                    label: "\(hermesNewsCount) HABER",
                    score: nil,
                    color: motorColor
                )
            }
            return .pending(label: "HABER TARANIYOR")

        case .athena:
            if let athena = viewModel.athenaResults[symbol] {
                let score = athena.factorScore
                let prefix: String
                if score >= 70 { prefix = "GÜÇ" }
                else if score >= 40 { prefix = "NÖT" }
                else { prefix = "ZAY" }
                return .active(
                    label: "\(prefix) · \(Int(score))",
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.athenaScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            return .pending(label: "FAKTÖR OKUNUYOR")

        case .demeter:
            if let demeter = viewModel.demeterScores.first {
                let score = demeter.totalScore
                return .active(
                    label: "\(demeter.grade.uppercased()) · \(Int(score))",
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            if let a = argus {
                let score = a.demeterScore
                return .active(
                    label: formatScoreLabel(score, action: nil),
                    score: clamp01(score / 100),
                    color: scoreColor(score)
                )
            }
            return .pending(label: "SEKTÖR OKUNUYOR")

        case .prometheus, .phoenix:
            // PhoenixAdvice iki kaynaktan biriyle gelebilir.
            let advice = dec?.phoenixAdvice ?? argus?.phoenixAdvice
            if let ph = advice {
                switch ph.status {
                case .active:
                    // Yön regressionSlope işaretinden (↑/↓/•).
                    let arrow: String
                    if let slope = ph.regressionSlope {
                        arrow = slope > 0 ? "↑" : (slope < 0 ? "↓" : "•")
                    } else {
                        arrow = "•"
                    }
                    return .active(
                        label: "\(arrow) \(Int(ph.confidence))",
                        score: clamp01(ph.confidence / 100),
                        color: scoreColor(ph.confidence)
                    )
                case .inactive:
                    return .active(
                        label: "PASİF",
                        score: nil,
                        color: InstitutionalTheme.Colors.textSecondary
                    )
                case .insufficientData:
                    return .pending(label: "VERİ KISITLI")
                case .error:
                    return .empty(label: "HATA")
                }
            }
            return .pending(label: "KANAL ARANIYOR")

        case .chiron:
            // Chiron rejim + öğrenme durumu. ArgusDecisionResult.chironResult
            // tek kaynaktır (Konsey grandDecision Chiron'u taşımaz).
            if let chiron = argus?.chironResult {
                let short = shortRegimeLabel(chiron.regime)
                // Öğrendiyse rozeti ekle: "TREND · AĞIRLIK YENİ"
                let learned = (chiron.learningNotes?.isEmpty == false)
                let label = learned ? "\(short) · YENİ" : short
                return .active(
                    label: label,
                    score: nil,
                    color: motorColor
                )
            }
            return .pending(label: "REJİM OKUNUYOR")

        case .alkindus:
            // Async insight — `alkindusInsight` @State'inden okunur.
            if let insight = alkindusInsight {
                let best = insight.bestModule.prefix(5).uppercased()
                let rate = Int(insight.bestHitRate * 100)
                return .active(
                    label: "\(best) %\(rate)",
                    score: clamp01(insight.bestHitRate),
                    color: motorColor
                )
            }
            if alkindusInsightLoaded {
                // Fetch bitti ama insight nil — 5'ten az karar var demektir.
                return .pending(label: "AZ VERİ")
            }
            return .pending(label: "ÖĞRENİYOR")

        default:
            return .empty(label: "—")
        }
    }

    /// `MarketRegime` uzun descriptor'ı yerine chip'e sığan kısa etiket.
    /// "Güçlü Trend" → "TREND", "Riskten Kaçış (Defansif)" → "RİSK-OFF" gibi.
    private func shortRegimeLabel(_ regime: MarketRegime) -> String {
        switch regime {
        case .neutral:    return "DENGE"
        case .trend:      return "TREND"
        case .chop:       return "YATAY"
        case .riskOff:    return "RİSK-OFF"
        case .newsShock:  return "HABER ŞOK"
        }
    }

    private func clamp01(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private func formatScoreLabel(_ score: Double, action: ProposedAction?) -> String {
        let prefix: String
        if let a = action {
            switch a {
            case .buy:  prefix = "AL"
            case .sell: prefix = "SAT"
            case .hold: prefix = "NÖT"
            }
        } else {
            prefix = score >= 60 ? "POZ" : (score <= 40 ? "NEG" : "NÖT")
        }
        return "\(prefix) · \(Int(score))"
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 60 { return InstitutionalTheme.Colors.aurora }
        if score <= 40 { return InstitutionalTheme.Colors.crimson }
        return InstitutionalTheme.Colors.textSecondary
    }

    // fundamentalsRows / formatMarketCap kaldırıldı (temel veriler gridi kaldırıldı).

    // MARK: - Hermes feed

    private var hermesNewsCount: Int {
        viewModel.newsBySymbol[symbol]?.count ?? 0
    }

    private var hermesItems: [HermesNewsItem] {
        guard let articles = viewModel.newsBySymbol[symbol] else { return [] }
        // NewsArticle'da impact yok — insights'tan sembol için ton çek
        let insights = viewModel.newsInsightsBySymbol[symbol] ?? []
        return articles.prefix(3).map { a in
            let matchedInsight = insights.first(where: { $0.headline == a.headline })
            let tone = matchedInsight.map { toneForInsight($0) } ?? .neutral
            return HermesNewsItem(
                id: a.id,
                tone: tone,
                source: String(a.source.prefix(20)),
                ageText: relativeTime(a.publishedAt),
                headline: a.headline
            )
        }
    }

    private func toneForInsight(_ insight: NewsInsight) -> HermesNewsItem.Tone {
        let score = insight.impactScore
        if score >= 65 { return .positive }
        if score <= 35 { return .negative }
        return .neutral
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "az önce" }
        if interval < 3600 { return "\(Int(interval / 60))dk" }
        if interval < 86400 { return "\(Int(interval / 3600))sa" }
        return "\(Int(interval / 86400))g"
    }

    // MARK: - Chart

    private var filteredCandles: [Candle] {
        let all = viewModel.candles[symbol] ?? []
        let take: Int
        switch selectedRange {
        case "1G":  take = min(all.count, 1)
        case "1H":  take = min(all.count, 5)
        case "1A":  take = min(all.count, 21)
        case "3A":  take = min(all.count, 63)
        case "6A":  take = min(all.count, 126)
        case "1Y":  take = min(all.count, 252)
        case "5Y":  take = all.count
        default:    take = min(all.count, 30)
        }
        return Array(all.suffix(take))
    }
}

// MARK: - Mini Line Chart (V5 chart alanı)

struct MiniLineChart: View {
    let candles: [Candle]
    var positive: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Grid
                VStack(spacing: 0) {
                    ForEach(0..<3) { _ in
                        Spacer()
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.border)
                            .frame(height: 0.5)
                    }
                }

                if candles.count >= 2 {
                    let closes = candles.map(\.close)
                    let minV = closes.min() ?? 0
                    let maxV = closes.max() ?? 1
                    let range = max(maxV - minV, 0.0001)
                    let w = geo.size.width
                    let h = geo.size.height

                    // Fill
                    Path { p in
                        let first = CGPoint(x: 0, y: h - CGFloat((closes[0] - minV) / range) * h)
                        p.move(to: CGPoint(x: 0, y: h))
                        p.addLine(to: first)
                        for (i, v) in closes.enumerated() {
                            let x = w * CGFloat(i) / CGFloat(closes.count - 1)
                            let y = h - CGFloat((v - minV) / range) * h
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                (positive ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson).opacity(0.28),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { p in
                        for (i, v) in closes.enumerated() {
                            let x = w * CGFloat(i) / CGFloat(closes.count - 1)
                            let y = h - CGFloat((v - minV) / range) * h
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        positive ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )

                    // Last dot
                    Circle()
                        .fill(positive ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson)
                        .frame(width: 6, height: 6)
                        .position(
                            x: w,
                            y: h - CGFloat((closes.last! - minV) / range) * h
                        )
                } else {
                    Text("Grafik verisi yok")
                        .font(InstitutionalTheme.Typography.dataMicro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Hermes news item (ekran içi tek kullanımlık model)

struct HermesNewsItem: Identifiable {
    let id: String
    let tone: Tone
    let source: String
    let ageText: String
    let headline: String

    enum Tone {
        case positive, neutral, negative

        var label: String {
            switch self {
            case .positive: return "POZ"
            case .neutral:  return "NÖT"
            case .negative: return "NEG"
            }
        }

        var color: Color {
            switch self {
            case .positive: return InstitutionalTheme.Colors.aurora
            case .neutral:  return InstitutionalTheme.Colors.holo
            case .negative: return InstitutionalTheme.Colors.crimson
            }
        }
    }
}

// MARK: - ArgusAction kısa etiket yardımcı

private extension ArgusAction {
    var shortLabel: String {
        switch self {
        case .aggressiveBuy: return "HÜCUM"
        case .accumulate:    return "AL"
        case .neutral:       return "BEKLE"
        case .trim:          return "AZALT"
        case .liquidate:     return "SAT"
        }
    }
}
