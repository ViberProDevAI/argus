import SwiftUI

// MARK: - ChironPerformanceView
//
// 2026-05-04 H-61 — sade refactor + back butonu düzeltildi.
// Eski: caps mono "CHIRON PERFORMANS" + bars3 menü ikonu (back yok!) +
// MotorLogo + tracking 0.6 caps section caption'lar.
// Yeni: chevron geri + sentence case "Performans" başlık + sade kart
// hiyerarşisi. Argus Ledger (SQLite) verisini çeker.
struct ChironPerformanceView: View {
    @State private var tradeHistory: [TradeRecord] = []
    @State private var learningEvents: [LearningEvent] = []
    @State private var isLoading = true

    @Environment(\.dismiss) private var dismiss
    // 2026-05-09: Settings → Motor kalibrasyonu → Performans gibi nested
    // NavigationLink push'larında `\.dismiss` her zaman güvenilir pop
    // tetiklemiyordu (kullanıcı raporu: geri dönüş yaptırmıyor). Eski
    // `\.presentationMode` API'si UIKit pop'a daha doğrudan bağlandığı
    // için fallback olarak tutuyoruz.
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            inlineTopNav

            ScrollView {
                VStack(spacing: 16) {
                    learningCard
                    tradeHistoryCard
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadData()
        }
    }

    // MARK: - Inline top nav

    private var inlineTopNav: some View {
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

            Text("Performans")
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

    // MARK: - Pop helper
    //
    // Önce yeni `\.dismiss` action'ını dener, etkisiz kaldıysa eski
    // `presentationMode.wrappedValue.dismiss()` ile fallback yapar.
    // Nested NavigationLink push'larında ikisinden biri mutlaka tetikler.
    private func popBack() {
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Öğrenme kartı

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Öğrenme günlüğü")
                    .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                Text("\(learningEvents.count)")
                    .font(DesignTokens.Fonts.custom(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .monospacedDigit()
            }

            Text("Modül ağırlıklarındaki son değişimler.")
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)

            if learningEvents.isEmpty {
                Text("Henüz kaydedilmiş ağırlık değişimi yok.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(learningEvents.prefix(3)) { event in
                    PerformanceLearningCard(event: event)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - İşlem geçmişi kartı

    private var tradeHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("İşlem geçmişi")
                    .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                if !tradeHistory.isEmpty {
                    Text("\(tradeHistory.count)")
                        .font(DesignTokens.Fonts.custom(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .monospacedDigit()
                }
            }

            Text("Argus Ledger · kapanmış pozisyonlar.")
                .font(DesignTokens.Fonts.custom(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            Rectangle()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 0.5)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.7)
                    Text("Yükleniyor…")
                        .font(DesignTokens.Fonts.custom(size: 13))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 6)
            } else if tradeHistory.isEmpty {
                Text("Henüz kapanmış işlem kaydı yok.")
                    .font(DesignTokens.Fonts.custom(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(tradeHistory) { trade in
                    TradeHistoryCard(trade: trade, lesson: nil)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func loadData() async {
        isLoading = true
        // Fetch real data from SQLite
        self.tradeHistory = await ArgusLedger.shared.getClosedTrades(limit: 20)
        self.learningEvents = await ArgusLedger.shared.loadLearningEvents(limit: 5)
        isLoading = false
    }
}

// MARK: - Subviews

struct PerformanceLearningCard: View {
    let event: LearningEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.reason)
                    .font(.caption)
                    .bold()
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Text(event.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            
            Text(event.summaryText)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.purple)
        }
        .padding(8)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }
}

