import SwiftUI

struct ServiceHealthView: View {
    @ObservedObject var monitor = ServiceHealthMonitor.shared
    
    var body: some View {
        List {
            Section(header: Text("API Durumu & Kotolar")) {
                ForEach(APIProvider.allCases) { provider in
                    if let status = monitor.providerStatuses[provider] {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(statusColor(status.status))
                                    .frame(width: 10, height: 10)
                                Text(provider.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text(status.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let remaining = status.remainingQuota {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Kalan Hak:")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(remaining) / \(status.totalQuota != nil ? "\(status.totalQuota!)" : "?")")
                                            .font(.caption)
                                            .bold()
                                    }
                                    
                                    if let total = status.totalQuota, total > 0 {
                                        ProgressView(value: Double(remaining), total: Double(total))
                                            .progressViewStyle(LinearProgressViewStyle(tint: statusColor(status.status)))
                                    }
                                }
                            } else {
                                Text("Kota bilgisi alınamıyor veya limitsiz.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let error = status.lastError {
                                Text("Son Hata: \(error)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            } else if let success = status.lastSuccess {
                                Text("Son İşlem: \(timeString(date: success))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section(header: Text("İşlem Günlüğü (Son 50)")) {
                ForEach(monitor.requestLog.reversed(), id: \.self) { log in
                    Text(log)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Sağlık Raporu")
    }
    
    private func statusColor(_ status: ServiceStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
    
    private func timeString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ServiceHealthView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceHealthView()
    }
}
