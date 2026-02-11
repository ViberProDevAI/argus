import SwiftUI

struct PhoenixRadarCard: View {
    @ObservedObject var scanner = PhoenixScannerService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                        .symbolEffect(.pulse, isActive: scanner.isScanning)
                    
                    Text("Phoenix Radar")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if scanner.isScanning {
                    Text("\(Int(scanner.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.gray)
                } else {
                    Button(action: {
                        Task { await scanner.runPipeline(mode: .balanced) }
                    }) {
                        Text("Tara")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                }
            }
            .padding()
            .background(Color(white: 0.1))
            
            // Content
            if scanner.latestCandidates.isEmpty {
                if scanner.isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        Text(scanner.currentStatus)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(height: 120)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Henüz sinyal yok")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Analizi başlatmak için 'Tara' butonuna basın.")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(height: 120)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(scanner.latestCandidates.prefix(5)) { candidate in
                            PhoenixCandidateItem(candidate: candidate)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(white: 0.07))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(scanner.isScanning ? 0.5 : 0.0), lineWidth: 1)
        )
    }
}

struct PhoenixCandidateItem: View {
    let candidate: PhoenixCandidate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(candidate.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if let score = candidate.evidence?.trendScore {
                    Text(String(format: "%.1f", score))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(score > 0 ? Color.green : Color.red)
                        .foregroundColor(.black)
                        .clipShape(Circle())
                }
            }
            
            Text(candidate.assetType.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .lineLimit(1)
            
            Text("$\(String(format: "%.2f", candidate.lastPrice))")
                .font(.caption)
                .foregroundColor(.gray)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            Text(candidate.level0Reason)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 24, alignment: .topLeading)
        }
        .padding(12)
        .frame(width: 140, height: 130)
        .background(Color(white: 0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
