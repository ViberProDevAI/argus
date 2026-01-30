import SwiftUI

// MARK: - Fund List View
// Main view for displaying the TEFAS fund watchlist

struct FundListView: View {
    @StateObject private var dataManager = FundDataManager.shared
    
    @State private var selectedCategory: FundCategory? = nil
    @State private var sortOption: FundDataManager.SortOption = .return1Week
    @State private var searchText = ""
    @State private var selectedFund: FundListItem? = nil
    
    var body: some View {
        // NavigationView removed for embedding in ArgusCockpitView
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Sort Picker
                sortPickerSection
                
                // MARK: - Category Filter
                categoryFilterSection
                
                // MARK: - Fund List
                if dataManager.isLoading && dataManager.fundPrices.isEmpty {
                    loadingView
                } else {
                    fundListSection
                }
            }
        }
        // .navigationTitle("Fonlar") // Managed by parent
        // .navigationBarTitleDisplayMode(.large)
         .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await dataManager.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.tint)
                }
                .disabled(dataManager.isLoading)
            }
        }
        .searchable(text: $searchText, prompt: "Fon ara...")
        .task {
            if dataManager.fundPrices.isEmpty {
                await dataManager.loadAllFunds()
            }
        }
        .sheet(item: $selectedFund) { fund in
            FundDetailView(fundCode: fund.code, fundName: fund.name)
        }
    }
    
    // MARK: - Sort Picker Section
    private var sortPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FundDataManager.SortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        Text(option.rawValue)
                            .font(.caption)
                            .fontWeight(sortOption == option ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                sortOption == option ?
                                Theme.tint.opacity(0.2) :
                                Theme.secondaryBackground
                            )
                            .foregroundColor(sortOption == option ? Theme.tint : .white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Category Filter Section
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                CategoryChip(
                    title: "Tümü",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                // Category chips
                ForEach(FundCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Fund List Section
    private var fundListSection: some View {
        List {
            ForEach(filteredFunds) { fund in
                FundRowView(
                    fund: fund,
                    priceData: dataManager.fundPrices[fund.code]
                )
                .listRowBackground(Theme.cardBackground)
                .listRowSeparatorTint(Color.gray.opacity(0.2))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFund = fund
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await dataManager.refresh()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.tint))
                .scaleEffect(1.5)
            
            Text("Fonlar yükleniyor...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filtered Funds
    private var filteredFunds: [FundListItem] {
        var funds = dataManager.sortedFunds(by: sortOption, category: selectedCategory)
        
        if !searchText.isEmpty {
            funds = funds.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.shortName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return funds
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.tint.opacity(0.2) : Theme.secondaryBackground)
            .foregroundColor(isSelected ? Theme.tint : .white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.tint : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Fund Row View

struct FundRowView: View {
    let fund: FundListItem
    let priceData: FundPriceData?
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: fund.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(categoryColor)
            }
            
            // Fund Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fund.code)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(fund.shortName)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                
                Text(fund.founder.rawValue)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // Returns
            VStack(alignment: .trailing, spacing: 4) {
                if let priceData = priceData, let return1W = priceData.return1Week {
                    Text(String(format: "%+.1f%%", return1W))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(return1W >= 0 ? Theme.positive : Theme.negative)
                    
                    Text("1 Hafta")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var categoryColor: Color {
        switch fund.category {
        case .hisse: return .blue
        case .paraPiyasasi: return .green
        case .kiymetliMaden: return .yellow
        case .borclanma: return .purple
        case .degisken: return .orange
        case .serbest: return .red
        case .fonSepeti: return .teal
        case .katilim: return .indigo
        case .karma: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    FundListView()
}
