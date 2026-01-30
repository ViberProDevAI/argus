import SwiftUI

struct ArgusDrawerView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var activeSheet: DrawerSheet?
    @StateObject private var termsRepository = FinanceTermsRepository.shared

    enum TabDestination: String {
        case home, markets, alkindus, portfolio, settings
    }

    var onNavigateToTab: ((TabDestination) -> Void)?

    enum DrawerSheet: Identifiable {
        case systemGuide
        case engineGuide
        case regimeGuide
        case dictionary
        case calendar
        case systemHealth
        case feedback

        var id: String {
            switch self {
            case .systemGuide: return "systemGuide"
            case .engineGuide: return "engineGuide"
            case .regimeGuide: return "regimeGuide"
            case .dictionary: return "dictionary"
            case .calendar: return "calendar"
            case .systemHealth: return "systemHealth"
            case .feedback: return "feedback"
            }
        }
    }

    var body: some View {
        ZStack {
            // Arka plan - tıklayınca kapat
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            HStack(spacing: 0) {
                // Drawer içeriği
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        searchSection
                        navigationSection
                        learnSection
                        toolsSection
                        systemSection
                        Spacer().frame(height: 32)
                    }
                    .padding(20)
                }
                .frame(width: 320)
                .background(Theme.cardBackground)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.accent)  // Cyber Blue instead of Gold
                        .frame(width: 2)
                }

                Spacer()
            }
        }
        .transition(.move(edge: .leading))
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ARGUS")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(3)

                Text("Yatirim Danismanlik Sistemi")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.05)))
            }
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
                .font(.subheadline)

            TextField("Terim veya ekran ara...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .stroke(Theme.tint.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("EKRANLAR")

            VStack(spacing: 8) {
                navigationItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Piyasa Ekrani",
                    subtitle: "Canli BIST verileri ve grafikler"
                ) {
                    navigateTo(.markets)
                }

                navigationItem(
                    icon: "briefcase.fill",
                    title: "Portfoy",
                    subtitle: "Pozisyonlar ve performans analizi"
                ) {
                    navigateTo(.portfolio)
                }

                navigationItem(
                    icon: "waveform.path.ecg",
                    title: "Sinyal Akisi",
                    subtitle: "Motor onerileri ve karar gecmisi"
                ) {
                    navigateTo(.home)
                }
            }
        }
    }

    // MARK: - Learn Section

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SISTEMI OGREN")

            VStack(spacing: 8) {
                navigationItem(
                    icon: "cpu",
                    title: "Argus Nasil Calisir?",
                    subtitle: "Veri akisi, motorlar, karar sureci"
                ) {
                    activeSheet = .systemGuide
                }

                navigationItem(
                    icon: "engine.combustion",
                    title: "Motor Rehberi",
                    subtitle: "Orion, Atlas, Phoenix, Chiron"
                ) {
                    activeSheet = .engineGuide
                }

                navigationItem(
                    icon: "gauge.with.dots.needle.33percent",
                    title: "Piyasa Rejimleri",
                    subtitle: "Trend, yatay, riskli donemleri anla"
                ) {
                    activeSheet = .regimeGuide
                }
            }
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ARACLAR")

            VStack(spacing: 8) {
                navigationItem(
                    icon: "calendar",
                    title: "Ekonomi Takvimi",
                    subtitle: "TCMB, FED kararlari ve onemli tarihler"
                ) {
                    activeSheet = .calendar
                }

                navigationItem(
                    icon: "character.book.closed",
                    title: "Finans Sozlugu",
                    subtitle: "\(termsRepository.totalCount) terim ve aciklama"
                ) {
                    activeSheet = .dictionary
                }
            }
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SISTEM")

            VStack(spacing: 8) {
                navigationItem(
                    icon: "gearshape",
                    title: "Ayarlar",
                    subtitle: "Tercihler ve konfigurasyon"
                ) {
                    navigateTo(.settings)
                }

                navigationItem(
                    icon: "heart.text.square",
                    title: "Sistem Durumu",
                    subtitle: "Veri baglantisi ve servis sagligi"
                ) {
                    activeSheet = .systemHealth
                }

                navigationItem(
                    icon: "envelope",
                    title: "Geri Bildirim",
                    subtitle: "Sorun bildir veya oneri gonder"
                ) {
                    activeSheet = .feedback
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)
                .tracking(1)

            Rectangle()
                .fill(Theme.tint.opacity(0.2))
                .frame(height: 1)
        }
    }

    private func navigationItem(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Theme.tint)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Color.white.opacity(0.02))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Navigation Helper

    private func navigateTo(_ destination: TabDestination) {
        isPresented = false
        onNavigateToTab?(destination)
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: DrawerSheet) -> some View {
        switch sheet {
        case .systemGuide:
            SystemGuideSheet()
        case .engineGuide:
            EngineGuideSheet()
        case .regimeGuide:
            RegimeGuideSheet()
        case .dictionary:
            FinanceDictionarySheet()
        case .calendar:
            EconomicCalendarSheet()
        case .systemHealth:
            SystemHealthSheet()
        case .feedback:
            FeedbackSheet()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ArgusDrawerView(isPresented: .constant(true))
    }
}
