import Combine
import SwiftUI

struct ArgusBadge: View {
    let score: Double
    var showLabel: Bool = true
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: 6) {
            // 1. Icon
            ArgusEyeView(mode: .argus, size: size)
            
            // 2. Text (Horizontal)
            if showLabel {
                Text("ARGUS")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .tracking(1) // Slight spacing for premium feel
                    .foregroundColor(InstitutionalTheme.Colors.holo)
            }
            
            // 3. Score
            Text("\(Int(score))")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scoreColor(score))
                .cornerRadius(6)
        }
        .padding(6)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.aurora }
        if score <= 40 { return InstitutionalTheme.Colors.crimson }
        return .orange
    }
}

// MARK: - Stale Data Badge
//
// Bir veri kaynağının tazelik durumunu (fresh / aging / stale / unknown) görsel olarak
// sunar. `StaleDataRegistry` ile birlikte kullanılır: kaynak `registry.touch("aether")`
// ile işaretlenir, view `registry.freshness("aether", expectedTTL: 300)` sorgular.
//
// Tasarım: iki satırlı kompakt rozet + renk noktası. Erişilebilirlik için label vardır.

struct StaleDataBadge: View {
    enum State {
        case fresh
        case aging
        case stale
        case unknown

        var color: Color {
            switch self {
            case .fresh:   return DesignTokens.Colors.fresh
            case .aging:   return DesignTokens.Colors.aging
            case .stale:   return DesignTokens.Colors.stale
            case .unknown: return DesignTokens.Colors.unknownFreshness
            }
        }

        var label: String {
            switch self {
            case .fresh:   return "Taze"
            case .aging:   return "Eskimekte"
            case .stale:   return "Güncel değil"
            case .unknown: return "Bilinmiyor"
            }
        }

        var symbol: String {
            switch self {
            case .fresh:   return "checkmark.circle.fill"
            case .aging:   return "clock.badge.exclamationmark"
            case .stale:   return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    let source: String          // Örn. "Aether skoru"
    let state: State
    var ageDescription: String? // Örn. "2 dk önce"

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: state.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(state.color)

            VStack(alignment: .leading, spacing: 0) {
                Text(source)
                    .font(DesignTokens.Fonts.micro)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                HStack(spacing: 4) {
                    Text(state.label)
                        .font(DesignTokens.Fonts.caption)
                        .foregroundStyle(state.color)
                    if let age = ageDescription {
                        Text("·")
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text(age)
                            .font(DesignTokens.Fonts.micro)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical,   DesignTokens.Spacing.xs)
        .background(
            Capsule().fill(state.color.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(state.color.opacity(0.30), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(source) durumu: \(state.label)\(ageDescription.map { ", \($0)" } ?? "")")
    }
}

// MARK: - Asenkron wrapper (StaleDataRegistry'den okuma)

struct AsyncStaleDataBadge: View {
    let source: String
    let registryKey: String
    let expectedTTL: TimeInterval
    var refreshInterval: TimeInterval = 10

    @State private var state: StaleDataBadge.State = .unknown
    @State private var ageText: String? = nil

    var body: some View {
        StaleDataBadge(source: source, state: state, ageDescription: ageText)
            .task(id: registryKey) { await refresh() }
            .onReceive(Timer.publish(every: refreshInterval, on: .main, in: .common).autoconnect()) { _ in
                Task { await refresh() }
            }
    }

    private func refresh() async {
        let freshness = await StaleDataRegistry.shared.freshness(registryKey, expectedTTL: expectedTTL)
        let age = await StaleDataRegistry.shared.ageSeconds(registryKey)
        await MainActor.run {
            switch freshness {
            case .fresh:   self.state = .fresh
            case .aging:   self.state = .aging
            case .stale:   self.state = .stale
            case .unknown: self.state = .unknown
            }
            self.ageText = age.map { formatAge($0) }
        }
    }

    private func formatAge(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60       { return "\(s) sn önce" }
        if s < 3600     { return "\(s / 60) dk önce" }
        if s < 86400    { return "\(s / 3600) sa önce" }
        return "\(s / 86400) gün önce"
    }
}
