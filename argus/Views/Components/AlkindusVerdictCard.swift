import SwiftUI

// MARK: - Alkindus Verdict Card
/// Alkindus'un kendi sesiyle tez sonucunu anlattığı kart.
/// TransactionDetailView içinde kapanmış pozisyonlar için görünür.

struct AlkindusVerdictCard: View {
    let verdict: AlkindusVerdict

    @State private var expanded = false

    // Neon colors (AlkindusAvatarView ile uyumlu)
    private let neonBlue  = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let ideaGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    private let errorRed  = Color(red: 1.0, green: 0.3, blue: 0.3)
    private let neonPurple = Color(red: 0.8, green: 0.2, blue: 1.0)

    private var accentColor: Color {
        verdict.wasCorrect ? ideaGreen : errorRed
    }

    // MARK: - Alkindus'un sesi

    private var speechText: String {
        let changeStr = String(format: "%+.1f", verdict.priceChange)
        let horizonStr = "T+\(verdict.horizon)"

        if verdict.wasCorrect {
            if verdict.action == "BUY" {
                return "\(horizonStr) günde tezim tuttu. \(verdict.symbol) için aldığım karar doğruydu — \(changeStr)% ile kapandı. Güzel."
            } else {
                return "\(horizonStr) günde tezim tuttu. \(verdict.symbol) için satış kararım haklıydı — \(changeStr)% ile geriledi. İyi korunmuş."
            }
        } else {
            if verdict.action == "BUY" {
                return "\(horizonStr) günde yanılmışım. \(verdict.symbol) — \(changeStr)% ile tezime ihanet etti. Bir şeyleri kaçırdım."
            } else {
                return "\(horizonStr) günde yanılmışım. \(verdict.symbol) için satış kararım hatalıydı — \(changeStr)% yükseldi. Sabırsızlık mıydı?"
            }
        }
    }

    private var regimeBadgeText: String {
        switch verdict.regime.lowercased() {
        case let r where r.contains("bull"): return "↑ Yükselen Piyasa"
        case let r where r.contains("bear"): return "↓ Düşen Piyasa"
        case let r where r.contains("neutral"): return "→ Nötr Piyasa"
        case let r where r.contains("volatile"): return "⚡ Volatil"
        default: return verdict.regime
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header strip
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ALKİNDUS SONUÇ ANALİZİ")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor.opacity(0.8))
                        .tracking(1.5)

                    Text("T+\(verdict.horizon) · \(verdict.evaluationDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                Spacer()

                // Verdict badge
                Text(verdict.wasCorrect ? "TEZ TUTTU" : "TEZ TURMADI")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor)
                    .cornerRadius(4)
                    .padding(.trailing, 12)
            }
            .background(accentColor.opacity(0.06))

            // MARK: Avatar + Speech
            HStack(alignment: .top, spacing: 14) {
                AlkindusAvatarView(
                    size: 52,
                    isThinking: !verdict.wasCorrect,
                    hasIdea: verdict.wasCorrect
                )
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    // Speech bubble
                    Text(speechText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(accentColor.opacity(0.25), lineWidth: 1)
                                )
                        )

                    // Price change + regime
                    HStack(spacing: 8) {
                        Text(String(format: "%+.1f%%", verdict.priceChange))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(verdict.priceChange >= 0 ? ideaGreen : errorRed)

                        Text(regimeBadgeText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 14)

            // MARK: Module Verdicts
            if !verdict.moduleVerdicts.isEmpty {
                Divider().background(Color.white.opacity(0.07))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(verdict.moduleVerdicts.sorted(by: { $0.module < $1.module }), id: \.module) { mv in
                            ModuleVerdictChip(mv: mv)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }

            // MARK: Original Reasoning (collapsible)
            if !verdict.originalReasoning.isEmpty && verdict.originalReasoning != "Gerekçe kaydedilmemiş" {
                Divider().background(Color.white.opacity(0.07))

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text("Karar Anındaki Gerekçe")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(verdict.originalReasoning)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Module Verdict Chip

private struct ModuleVerdictChip: View {
    let mv: ModuleVerdict

    private let ideaGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    private let errorRed  = Color(red: 1.0, green: 0.3, blue: 0.3)

    var body: some View {
        HStack(spacing: 4) {
            Text(mv.module.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))

            Text("\(Int(mv.score))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)

            Image(systemName: mv.wasCorrect ? "checkmark" : "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(mv.wasCorrect ? ideaGreen : errorRed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke((mv.wasCorrect ? ideaGreen : errorRed).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Async Loader
/// Verdict'leri symbol bazlı yükleyip en güncelini gösteren wrapper.
struct AlkindusVerdictSection: View {
    let symbol: String

    @State private var verdicts: [AlkindusVerdict] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded && !verdicts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alkindus Dedi Ki...")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)

                    ForEach(verdicts.prefix(3)) { verdict in
                        AlkindusVerdictCard(verdict: verdict)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .task {
            verdicts = await AlkindusMemoryStore.shared.loadVerdicts(for: symbol)
            loaded = true
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            AlkindusVerdictCard(verdict: AlkindusVerdict(
                symbol: "AAPL",
                action: "BUY",
                decisionDate: Date().addingTimeInterval(-7 * 86400),
                evaluationDate: Date(),
                horizon: 7,
                wasCorrect: true,
                priceChange: 4.2,
                regime: "Bull",
                moduleVerdicts: [
                    ModuleVerdict(module: "Orion", score: 82, wasCorrect: true),
                    ModuleVerdict(module: "Atlas", score: 41, wasCorrect: false),
                    ModuleVerdict(module: "Lyra", score: 75, wasCorrect: true),
                ],
                originalReasoning: "Teknik görünüm güçlü, momentum pozitif, hacim destekliyor."
            ))

            AlkindusVerdictCard(verdict: AlkindusVerdict(
                symbol: "BIST100",
                action: "BUY",
                decisionDate: Date().addingTimeInterval(-15 * 86400),
                evaluationDate: Date(),
                horizon: 15,
                wasCorrect: false,
                priceChange: -8.3,
                regime: "Bear",
                moduleVerdicts: [
                    ModuleVerdict(module: "Orion", score: 68, wasCorrect: false),
                    ModuleVerdict(module: "Atlas", score: 55, wasCorrect: false),
                ],
                originalReasoning: "Destek seviyesinde alım yapıldı ancak global satış baskısı aşılamadı."
            ))
        }
        .padding(.vertical, 20)
    }
    .background(Color.black)
}
