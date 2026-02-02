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
            }
        }
    }

    private var sections: [DrawerSection] {
        buildSections { sheet in
            activeSheet = sheet
        }
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
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        searchSection

                        if !searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("ARAMA SONUCLARI")
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
                .frame(width: 320)
                .background(Theme.cardBackground)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.accent)
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(3)

                Text("Yatirim Danismanlik Sistemi")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button { isPresented = false } label: {
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

            TextField("Islem veya ekran ara...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.tint.opacity(0.1), lineWidth: 1))
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
                .foregroundColor(Theme.tint)
        }
    }

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

    private func navigationItem(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconView(for: icon)
                    .frame(width: 28, height: 28)
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
            .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Color.white.opacity(0.02)))
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
        }
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
