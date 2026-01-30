import SwiftUI

struct FinanceDictionarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = FinanceTermsRepository.shared
    @State private var selectedTerm: FinanceTerm?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                categoryFilter
                termsList
            }
            .background(Theme.background)
            .navigationTitle("Finans Sozlugu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
        }
        .sheet(item: $selectedTerm) { term in
            TermDetailSheet(term: term)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)

            TextField("Terim ara...", text: $repository.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)

            if !repository.searchQuery.isEmpty {
                Button {
                    repository.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: "Tumu")

                ForEach(FinanceTermCategory.allCases) { category in
                    categoryChip(category, title: category.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.cardBackground.opacity(0.5))
    }

    private func categoryChip(_ category: FinanceTermCategory?, title: String) -> some View {
        let isSelected = repository.selectedCategory == category

        return Button {
            repository.selectedCategory = category
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? Theme.background : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .fill(isSelected ? Theme.tint : Color.white.opacity(0.1))
                )
        }
    }

    // MARK: - Terms List

    private var termsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(repository.filteredTerms) { term in
                    termRow(term)
                }
            }
            .padding(.top, 8)
        }
    }

    private func termRow(_ term: FinanceTerm) -> some View {
        Button {
            selectedTerm = term
        } label: {
            HStack(spacing: 12) {
                Image(systemName: term.category.icon)
                    .font(.subheadline)
                    .foregroundColor(Theme.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(term.term)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        if let fullName = term.fullName {
                            Text("(\(fullName))")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    Text(term.definition)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Term Detail Sheet

struct TermDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let term: FinanceTerm

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Baslik
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.term)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if let fullName = term.fullName {
                            Text(fullName)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }

                        HStack {
                            Image(systemName: term.category.icon)
                                .font(.caption)
                            Text(term.category.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(Theme.tint)
                        .padding(.top, 4)
                    }

                    Divider().background(Theme.tint.opacity(0.3))

                    // Tanim
                    sectionContent("TANIM", content: term.definition)

                    // Formul
                    if let formula = term.formula {
                        sectionContent("FORMUL", content: formula, isCode: true)
                    }

                    // Argus Kullanimi
                    if let argusUsage = term.argusUsage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ARGUS'TA KULLANIMI")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textSecondary)

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "cpu")
                                    .foregroundColor(Theme.tint)
                                    .font(.subheadline)

                                Text(argusUsage)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Theme.tint.opacity(0.1))
                            .cornerRadius(Theme.Radius.small)
                        }
                    }

                    // Ilgili Terimler
                    if !term.relatedTerms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ILGILI TERIMLER")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(term.relatedTerms, id: \.self) { related in
                                    Text(related)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(Theme.Radius.small)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(term.term)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
        }
    }

    private func sectionContent(_ title: String, content: String, isCode: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)

            Text(content)
                .font(isCode ? .system(.subheadline, design: .monospaced) : .subheadline)
                .foregroundColor(isCode ? Theme.tint : .white)
                .padding(isCode ? 12 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isCode ? Color.white.opacity(0.05) : Color.clear)
                .cornerRadius(isCode ? Theme.Radius.small : 0)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    FinanceDictionarySheet()
}
