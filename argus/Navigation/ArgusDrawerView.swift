import SwiftUI

struct ArgusDrawerView: View {
    @Binding var isPresented: Bool
    let buildSections: (_ openSheet: @escaping (DrawerSheet) -> Void) -> [DrawerSection]

    @State private var searchText = ""
    @State private var activeSheet: DrawerSheet?

    struct DrawerSection: Identifiable {
        let id = UUID()
        let title: String
        let items: [DrawerItem]
    }

    struct DrawerItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let action: () -> Void
    }

    enum DrawerSheet: Identifiable {
        case systemGuide
        case engineGuide
        case regimeGuide
        case dictionary
        case calendar
        case systemHealth
        case feedback
        case alkindusGuide
        case financeWisdom
        case academyHub

        var id: String {
            switch self {
            case .systemGuide: return "systemGuide"
            case .engineGuide: return "engineGuide"
            case .regimeGuide: return "regimeGuide"
            case .dictionary: return "dictionary"
            case .calendar: return "calendar"
            case .systemHealth: return "systemHealth"
            case .feedback: return "feedback"
            case .alkindusGuide: return "alkindusGuide"
            case .financeWisdom: return "financeWisdom"
            case .academyHub: return "academyHub"
            }
        }
    }

    private var sections: [DrawerSection] {
        let baseSections = buildSections { sheet in
            activeSheet = sheet
        }
        return withAcademyShortcut(baseSections)
    }

    private var allItems: [DrawerItem] {
        sections.flatMap { $0.items }
    }

    private var filteredItems: [DrawerItem] {
        if searchText.isEmpty { return [] }
        return allItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        searchSection

                        if !searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("ARAMA SONUÇLARI")
                                VStack(spacing: 8) {
                                    ForEach(filteredItems) { item in
                                        navigationItem(icon: item.icon, title: item.title, subtitle: item.subtitle, action: item.action)
                                    }
                                }
                            }
                        } else {
                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: 12) {
                                    sectionHeader(section.title)
                                    VStack(spacing: 8) {
                                        ForEach(section.items) { item in
                                            navigationItem(icon: item.icon, title: item.title, subtitle: item.subtitle, action: item.action)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 32)
                    }
                    .padding(20)
                }
                .frame(width: 332)
                .background(InstitutionalTheme.Colors.surface1)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(InstitutionalTheme.Colors.primary)
                        .frame(width: 2)
                }

                Spacer()
            }
        }
        .transition(.move(edge: .leading))
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .onDisappear {
                    isPresented = false
                }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ARGUS")
                    .font(InstitutionalTheme.Typography.headline)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .tracking(3)

                Text("Eğitici Piyasa Analiz Programı")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .padding(8)
                    .background(Circle().fill(InstitutionalTheme.Colors.surface2))
            }
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .font(.subheadline)

            TextField("İşlem veya ekran ara...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .font(InstitutionalTheme.Typography.caption)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).fill(InstitutionalTheme.Colors.surface2))
        .overlay(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1))
    }

    // MARK: - Components

    @ViewBuilder
    private func iconView(for icon: String) -> some View {
        if icon.hasSuffix("Icon") {
            // Custom asset icon (OrionIcon, AtlasIcon, etc.)
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // SF Symbol
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(InstitutionalTheme.Colors.primary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .tracking(1)
            Rectangle()
                .fill(InstitutionalTheme.Colors.primary.opacity(0.25))
                .frame(height: 1)
        }
    }

    private func navigationItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconView(for: icon)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(InstitutionalTheme.Typography.bodyStrong)
                        .fontWeight(.medium)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm).fill(InstitutionalTheme.Colors.surface2))
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

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
        case .alkindusGuide:
            AlkindusEducationSheet()
        case .financeWisdom:
            FinanceWisdomSheet()
        case .academyHub:
            ArgusAcademyHubSheet()
        }
    }

    private func withAcademyShortcut(_ baseSections: [DrawerSection]) -> [DrawerSection] {
        let academyItem = DrawerItem(
            title: "Argus Akademi",
            subtitle: "Sistem ve motor eğitimi",
            icon: "graduationcap"
        ) {
            activeSheet = .academyHub
        }

        var updated: [DrawerSection] = []
        var hadLearningItems = false

        for section in baseSections {
            let filteredItems = section.items.filter { item in
                let isLearning = isLearningItem(item.title)
                if isLearning { hadLearningItems = true }
                return !isLearning
            }
            if !filteredItems.isEmpty {
                updated.append(DrawerSection(title: section.title, items: filteredItems))
            }
        }

        let alreadyHasAcademy = updated
            .flatMap(\.items)
            .contains { normalized($0.title).contains("akademi") }

        guard !alreadyHasAcademy else { return updated }

        if let toolsIndex = updated.firstIndex(where: { normalized($0.title).contains("arac") }) {
            let targetSection = updated[toolsIndex]
            let sectionWithAcademy = DrawerSection(
                title: targetSection.title,
                items: [academyItem] + targetSection.items
            )
            updated[toolsIndex] = sectionWithAcademy
            return updated
        }

        if hadLearningItems {
            updated.insert(DrawerSection(title: "ÖĞRENME", items: [academyItem]), at: 0)
            return updated
        }

        updated.append(DrawerSection(title: "ÖĞRENME", items: [academyItem]))
        return updated
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
    }

    private func isLearningItem(_ title: String) -> Bool {
        let normalizedTitle = normalized(title)
        return normalizedTitle.contains("egitim") || normalizedTitle.contains("rehber") || normalizedTitle.contains("akademi")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ArgusDrawerView(isPresented: .constant(true)) { _ in
            [
                ArgusDrawerView.DrawerSection(
                    title: "ORNEK",
                    items: [
                        ArgusDrawerView.DrawerItem(title: "Demo", subtitle: "Ornek aksiyon", icon: "gearshape", action: {})
                    ]
                )
            ]
        }
    }
}
