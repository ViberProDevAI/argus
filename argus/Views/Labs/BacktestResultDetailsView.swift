import SwiftUI
import Charts

struct BacktestResultDetailsView: View {
    let result: BacktestResult
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    BacktestStatCard(title: "Toplam Getiri", value: String(format: "%.2f%%", result.totalReturn), color: result.totalReturn >= 0 ? .green : .red)
                    BacktestStatCard(title: "Son Sermaye", value: String(format: "$%.0f", result.finalCapital), color: .primary)
                    BacktestStatCard(title: "Max Drawdown", value: String(format: "%.2f%%", result.maxDrawdown), color: .orange)
                    BacktestStatCard(title: "İşlem Sayısı", value: "\(result.trades.count)", color: .blue)
                }
                .padding(.horizontal)
                
                // 2. Visual Price Chart (Trades)
                VStack(alignment: .leading) {
                    Text("İşlem Grafiği")
                        .font(.headline)
                        .padding(.leading)
                    
                    Chart {
                        // Price Line
                        ForEach(result.candles) { candle in
                            LineMark(
                                x: .value("Tarih", candle.date),
                                y: .value("Fiyat", candle.close)
                            )
                            .foregroundStyle(.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        }
                        
                        // Buy/Sell Markers
                        ForEach(result.trades) { trade in
                            // Entry Marker
                            PointMark(
                                x: .value("Tarih", trade.entryDate),
                                y: .value("Fiyat", trade.entryPrice)
                            )
                            .symbol(.circle)
                            .foregroundStyle(.green)
                            .annotation(position: .top) {
                                Text("AL")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            // Exit Marker (if completed)
                            if trade.exitPrice > 0 {
                                PointMark(
                                    x: .value("Tarih", trade.exitDate),
                                    y: .value("Fiyat", trade.exitPrice)
                                )
                                .symbol(.square)
                                .foregroundStyle(.red)
                                .annotation(position: .bottom) {
                                    Text("SAT")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // 3. Equity Curve
                VStack(alignment: .leading) {
                    Text("Sermaye Eğrisi")
                        .font(.headline)
                        .padding(.leading)
                    
                    Chart(result.equityCurve) { point in
                        LineMark(
                            x: .value("Tarih", point.date),
                            y: .value("Değer", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.tint.gradient)
                    }
                    .frame(height: 250)
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // 3. Trade List (Last 5)
                VStack(alignment: .leading) {
                    Text("Son İşlemler")
                        .font(.headline)
                        .padding(.leading)
                    
                    if result.trades.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "eyes")
                                .font(.largeTitle)
                                .foregroundColor(Theme.tint)
                            Text("Argus bu dönemde hiç alım fırsatı bulamadı.")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("Skorlar alım eşiğinin (60) altında kaldı (Güvenli Mod).")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        ForEach(result.trades.suffix(5).reversed()) { trade in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(trade.type.rawValue)
                                        .bold()
                                        .foregroundColor(trade.pnl >= 0 ? .green : .red)
                                    Text(trade.entryDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(String(format: "%+.2f", trade.pnl))
                                        .bold()
                                        .foregroundColor(trade.pnl >= 0 ? .green : .red)
                                    Text(String(format: "%.2f%%", trade.pnlPercent))
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background(Theme.secondaryBackground)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }

                // 4. Detailed Logs (Son 100)
                VStack(alignment: .leading) {
                    Text("Günlük Kayıtlar (Son 100)")
                        .font(.headline)
                        .padding(.leading)
                        .padding(.top)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(result.logs.suffix(100).reversed()) { log in
                                HStack {
                                    Text(log.date.formatted(date: .numeric, time: .omitted))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Text("$\(String(format: "%.1f", log.price))")
                                        .font(.caption2)
                                        .bold()
                                        .frame(width: 60, alignment: .trailing)
                                        
                                    Spacer()
                                    
                                    Text(log.details)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    Text(String(format: "%.1f", log.score))
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(log.score >= 60 ? .green : (log.score < 45 ? .red : .orange))
                                        .frame(width: 40)
                                    
                                    Text(log.action == "BUY" ? "AL" : (log.action == "SELL" ? "SAT" : "TUT"))
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(log.action == "BUY" ? Color.green.opacity(0.2) : (log.action == "SELL" ? Color.red.opacity(0.2) : Color.gray.opacity(0.1)))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Theme.secondaryBackground.opacity(0.5))
                                .overlay(Rectangle().frame(height: 0.5).foregroundColor(.gray.opacity(0.1)), alignment: .bottom)
                            }
                        }
                    }
                    .frame(height: 300)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Test Sonuçları: \(result.config.strategy.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
