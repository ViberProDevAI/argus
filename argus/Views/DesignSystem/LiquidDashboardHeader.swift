import SwiftUI

// MARK: - Liquid Dashboard Header
/// Portföy görünümü için birleşik başlık.
/// Liquid Effect, bakiye bilgileri ve kontrol butonlarını (Brain, Geçmiş, Pazar Seçimi) içerir.
struct LiquidDashboardHeader: View {
    @ObservedObject var viewModel: TradingViewModel
    @Binding var selectedMarket: TradeMarket
    
    // Actions
    var onBrainTap: () -> Void
    var onHistoryTap: () -> Void
    var onDrawerTap: () -> Void // New Action
    
    private var isBist: Bool { selectedMarket == .bist }
    
    // Dynamic Colors
    private var themeColor: Color { isBist ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.primary }
    private var currencySymbol: String { isBist ? "₺" : "$" }
    
    // Data Calculation
    // Data Calculation
    private var equity: Double {
        isBist ? viewModel.getBistEquity() : viewModel.getEquity()
    }
    
    private var balance: Double {
        isBist ? viewModel.bistBalance : viewModel.balance
    }
    
    private var realized: Double {
        viewModel.getRealizedPnL(market: selectedMarket)
    }
    
    private var unrealized: Double {
        isBist ? viewModel.getBistUnrealizedPnL() : viewModel.getUnrealizedPnL()
    }
    
    var body: some View {
        ZStack(alignment: .top) { // Bottom yerine Top alignment
            // A. BACKGROUND (Liquid Effect) - Daha kompakt
            LiquidEffectView(
                color: themeColor,
                intensity: isBist ? 0.8 : 0.6
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)) // Yuvarlatma azaltıldı
            .shadow(color: themeColor.opacity(0.2), radius: 15, x: 0, y: 8)
            
            // B. CONTENT LAYER
            VStack(spacing: 16) { // Spacing azaltıldı
                // 1. Top Control Bar (Market Switcher & Buttons)
                HStack {
                    // Custom Glass Segmented Control - Daha ince
                    HStack(spacing: 0) {
                        marketToggle(title: "Global", mode: .global)
                        marketToggle(title: "BIST", mode: .bist)
                    }
                    .padding(3)
                    .background(InstitutionalTheme.Colors.surface2.opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1))
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        glassIconButton(icon: "line.3.horizontal", action: onDrawerTap) // Drawer Button
                        glassIconButton(icon: "brain.head.profile", action: onBrainTap)
                        glassIconButton(icon: "clock.arrow.circlepath", action: onHistoryTap)
                    }
                }
                
                // 2. Main Balance (Center)
                VStack(spacing: 4) {
                    Text(isBist ? "BIST DEĞERİ" : "TOPLAM VARLIK")
                        .font(InstitutionalTheme.Typography.micro)
                        .tracking(1.5)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    // Ana Bakiye - Küçültüldü (48 -> 36)
                    Text("\(currencySymbol)\(String(format: "%.0f", equity))")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .shadow(color: themeColor.opacity(0.3), radius: 10)
                }
                
                // 3. Stats Grid (3 Columns)
                HStack(spacing: 12) {
                    // Nakit
                    statPill(title: "NAKİT", value: balance, color: InstitutionalTheme.Colors.textPrimary)
                    
                    // Net K/Z (Toplam)
                    statPill(title: "NET K/Z", value: realized + unrealized, color: (realized + unrealized) >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                    
                    // Anlık K/Z (Unrealized) - YENİ
                    statPill(title: "ANLIK", value: unrealized, color: unrealized >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                }
                .padding(.bottom, 8)
            }
            .padding(16) // Padding azaltıldı
        }
        // Sabit frame height kaldırıldı, içeriğe göre şekil alacak
    }
    
    // MARK: - Subviews
    
    private func marketToggle(title: String, mode: TradeMarket) -> some View {
        Button(action: {
            withAnimation(.spring()) { selectedMarket = mode }
        }) {
            Text(title)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(selectedMarket == mode ? themeColor : InstitutionalTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedMarket == mode ? InstitutionalTheme.Colors.textPrimary : Color.clear
                )
                .clipShape(Capsule())
                // Invert text color if selected (White bg -> Theme color text)
                .foregroundColor(selectedMarket == mode ? themeColor : InstitutionalTheme.Colors.textPrimary)
        }
    }
    
    private func glassIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(InstitutionalTheme.Colors.surface2.opacity(0.95))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderStrong, lineWidth: 1)
                )
        }
    }
    
    private func statPill(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                
                Text("\(currencySymbol)\(String(format: "%.0f", value))")
                    .font(InstitutionalTheme.Typography.data)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface2.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
