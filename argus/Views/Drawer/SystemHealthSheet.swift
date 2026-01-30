import SwiftUI

struct SystemHealthSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewSection
                    servicesSection
                    dataSourcesSection
                    performanceSection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Sistem Durumu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(Theme.tint)
                }
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Theme.positive)
                    .frame(width: 10, height: 10)

                Text("Sistem Calisiyor")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()

                Text("Son guncelleme: Simdi")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(Theme.Radius.medium)
        }
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SERVISLER")

            VStack(spacing: 8) {
                serviceRow("Orion Motoru", status: .active)
                serviceRow("Atlas Motoru", status: .active)
                serviceRow("Phoenix Motoru", status: .active)
                serviceRow("Chiron Motoru", status: .active)
                serviceRow("Alkindus AI", status: .active)
            }
        }
    }

    // MARK: - Data Sources

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("VERI KAYNAKLARI")

            VStack(spacing: 8) {
                dataSourceRow("BIST Veri Akisi", status: .connected, latency: "< 1sn")
                dataSourceRow("Yahoo Finance", status: .connected, latency: "~ 2sn")
                dataSourceRow("TCMB Verileri", status: .connected, latency: "Gunluk")
            }
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PERFORMANS")

            VStack(spacing: 8) {
                performanceRow("Bellek Kullanimi", value: "Normal")
                performanceRow("CPU Kullanimi", value: "Dusuk")
                performanceRow("Onbellek Durumu", value: "Aktif")
            }

            Text("Performans verileri yaklasik degerlerdir.")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .italic()
                .padding(.top, 4)
        }
    }

    // MARK: - Components

    private enum ServiceStatus {
        case active, warning, error

        var color: Color {
            switch self {
            case .active: return Theme.positive
            case .warning: return Theme.warning
            case .error: return Theme.negative
            }
        }

        var text: String {
            switch self {
            case .active: return "Aktif"
            case .warning: return "Uyari"
            case .error: return "Hata"
            }
        }
    }

    private enum ConnectionStatus {
        case connected, slow, disconnected

        var color: Color {
            switch self {
            case .connected: return Theme.positive
            case .slow: return Theme.warning
            case .disconnected: return Theme.negative
            }
        }

        var text: String {
            switch self {
            case .connected: return "Bagli"
            case .slow: return "Yavas"
            case .disconnected: return "Baglanti Yok"
            }
        }
    }

    private func serviceRow(_ name: String, status: ServiceStatus) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)

                Text(status.text)
                    .font(.caption2)
                    .foregroundColor(status.color)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    private func dataSourceRow(_ name: String, status: ConnectionStatus, latency: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            Text(latency)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)

                Text(status.text)
                    .font(.caption2)
                    .foregroundColor(status.color)
            }
            .frame(width: 70)
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    private func performanceRow(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundColor(Theme.tint)
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(Theme.Radius.small)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Theme.textSecondary)
            .tracking(0.5)
    }
}

#Preview {
    SystemHealthSheet()
}
