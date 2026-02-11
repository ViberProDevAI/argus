import SwiftUI

struct RequestTraceListView: View {
    @StateObject private var telepresence = HeimdallTelepresence.shared.telemetry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("CANLI İSTEK AKIŞI (TRACE)")
                .font(.caption)
                .bold()
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    if telepresence.recentTraces.isEmpty {
                        Text("Veri akışı bekleniyor...")
                            .foregroundColor(Theme.textSecondary)
                            .padding()
                    } else {
                        ForEach(telepresence.recentTraces) { trace in
                            TraceRow(trace: trace)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 300) // Fixed height scroll area
        }
        .padding(.vertical)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
}

struct TraceRow: View {
    let trace: RequestTraceEvent
    @State private var showDetails = false
    
    var statusColor: Color {
        if trace.isSuccess { return .green }
        switch trace.failureCategory {
        case .rateLimited: return .purple
        case .authInvalid: return .red
        case .entitlementDenied: return .yellow
        case .networkError: return .blue
        case .serverError: return .orange
        case .circuitOpen: return .gray
        default: return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status Dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Method / Provider
                Text(trace.provider.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text("•")
                    .foregroundColor(Theme.textSecondary)
                
                if !trace.endpoint.isEmpty {
                    Text(trace.endpoint) // or trace.engine.rawValue
                         .font(.caption2)
                         .foregroundColor(Theme.textSecondary)
                } else {
                    Text(trace.engine.rawValue)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                 
                Spacer()
                
                // Duration
                Text(String(format: "%.0fms", trace.durationMs * 1000))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Symbol & Result
            HStack {
                Text(trace.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !trace.isSuccess {
                    Text(trace.failureCategory.rawValue)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(statusColor)
                        .padding(2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("\(trace.byteCount)B")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            if showDetails {
                Divider().background(Theme.border)
                VStack(alignment: .leading, spacing: 4) {
                    if let err = trace.errorMessage {
                        Text("Hata: \(err)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    if let code = trace.httpStatusCode {
                        Text("HTTP Status: \(code)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    if let body = trace.bodyPrefix {
                        Text("Payload Prefix:")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.gray)
                        Text(body)
                            .font(.caption2)
                            .fontDesign(.monospaced) // Code font
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(4)
                    }
                    
                    if let asset = trace.canonicalAsset {
                        Text("Canonical Asset: \(asset.rawValue)")
                             .font(.caption2)
                             .foregroundColor(.purple)
                    }

                    Text("ID: \(trace.id.description)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Theme.background)
        .cornerRadius(8)
        .onTapGesture {
            withAnimation { showDetails.toggle() }
        }
    }
}
