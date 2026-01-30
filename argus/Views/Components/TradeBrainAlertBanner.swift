import SwiftUI

// MARK: - Trade Brain Alert Banner
/// Plan tetiklenmelerini ve bildirimleri gösteren banner

struct TradeBrainAlertBanner: View {
    let alert: TradeBrainAlert
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(alert.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                
                Text(alert.actionDescription)
                    .font(.caption)
                    .foregroundColor(Theme.tint)
            }
            
            Spacer()
            
            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .shadow(color: iconColor.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch alert.type {
        case .planTriggered: return "brain.head.profile"
        case .targetReached: return "target"
        case .stopApproaching: return "exclamationmark.triangle.fill"
        case .councilChanged: return "person.3.fill"
        }
    }
    
    private var iconColor: Color {
        switch alert.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Alert List View (For Settings/History)

struct TradeBrainAlertListView: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if viewModel.planAlerts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.textSecondary.opacity(0.3))
                        
                        Text("Bildirim Yok")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Plan tetiklenmesi olduğunda burada görünecek")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.planAlerts) { alert in
                                TradeBrainAlertBanner(
                                    alert: alert,
                                    onDismiss: {
                                        ExecutionStateViewModel.shared.planAlerts.removeAll { $0.id == alert.id }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trade Brain Bildirimleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.planAlerts.isEmpty {
                        Button("Tümünü Temizle") {
                            ExecutionStateViewModel.shared.planAlerts.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

#Preview {
    TradeBrainAlertBanner(
        alert: TradeBrainAlert(
            type: .planTriggered,
            symbol: "AAPL",
            message: "Hedef fiyata ulaşıldı! %30 satış önerisi.",
            actionDescription: "ATR × 2 ($185.50): %30 sat",
            priority: .medium
        ),
        onDismiss: {}
    )
    .padding()
    .background(Theme.background)
}
