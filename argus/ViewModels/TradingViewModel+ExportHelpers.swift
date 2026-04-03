import Foundation

// MARK: - Export Helpers & Decision Context Builders (extracted from TradingViewModel)

extension TradingViewModel {

    func makeDecisionTraceSnapshot(from snapshot: DecisionSnapshot, mode: String) -> DecisionTraceSnapshot {
        return DecisionTraceSnapshot(
            mode: mode,
            overallScore: 50.0,
            scores: DecisionTraceSnapshot.ScoresSnapshot(
                atlas: (snapshot.evidence.first(where: { $0.module == "Atlas" })?.confidence ?? 0.0) * 100,
                orion: (snapshot.evidence.first(where: { $0.module == "Orion" })?.confidence ?? 0.0) * 100,
                aether: snapshot.riskContext?.aetherScore ?? 50.0,
                hermes: 50.0,
                demeter: 50.0
            ),
            thresholds: DecisionTraceSnapshot.ThresholdsSnapshot(
                buyOverallMin: 0, sellOverallMin: 0, orionMin: 0, atlasMin: 0, aetherMin: 0, hermesMin: 0
            ),
            reasonsTop3: snapshot.dominantSignals.map {
                DecisionTraceSnapshot.ReasonSnapshot(key: "Signal", value: nil, note: $0)
            },
            guards: DecisionTraceSnapshot.GuardsSnapshot(
                cooldownActive: snapshot.locks.cooldownUntil != nil,
                minHoldBlocked: snapshot.locks.minHoldUntil != nil,
                minMoveBlocked: false,
                costGateBlocked: false,
                rebalanceBandBlocked: false,
                rateLimitBlocked: snapshot.locks.isLocked,
                otherBlocked: snapshot.locks.isLocked
            ),
            blockReason: snapshot.locks.isLocked ? snapshot.reasonOneLiner : nil,
            phoenix: snapshot.phoenix,
            standardizedOutputs: snapshot.standardizedOutputs
        )
    }

    func makeMarketSnapshot(for symbol: String, currentPrice: Double) -> MarketSnapshot {
        return MarketSnapshot(
            bid: currentPrice, ask: currentPrice, spreadPct: 0.0, atr: nil,
            returns: MarketSnapshot.ReturnsSnapshot(r1m: nil, r5m: nil, r1h: nil, r1d: nil, rangePct: nil, gapPct: nil),
            barsSummary: MarketSnapshot.BarsSummarySnapshot(lookback: 20, high: nil, low: nil, close: currentPrice),
            barTimestamp: Date(),
            signalPrice: currentPrice,
            volatilityHint: nil
        )
    }

    func makeDecisionContext(fromTrace trace: DecisionTraceSnapshot) -> DecisionContext {
        return DecisionContext(
            decisionId: UUID().uuidString,
            overallAction: "BUY",
            dominantSignals: trace.reasonsTop3.compactMap { $0.note },
            conflicts: [],
            moduleVotes: ModuleVotes(
                atlas: ModuleVote(score: trace.scores.atlas ?? 0.0, direction: "BUY", confidence: (trace.scores.atlas ?? 0.0) / 100.0),
                orion: ModuleVote(score: trace.scores.orion ?? 0.0, direction: "BUY", confidence: (trace.scores.orion ?? 0.0) / 100.0),
                aether: ModuleVote(score: trace.scores.aether ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                hermes: ModuleVote(score: trace.scores.hermes ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                chiron: nil
            )
        )
    }

    func makeDecisionContext(from snapshot: DecisionSnapshot) -> DecisionContext {
        let findVote = { (module: String) -> ModuleVote? in
            guard let ev = snapshot.evidence.first(where: { $0.module == module }) else { return nil }
            return ModuleVote(score: ev.confidence, direction: ev.direction, confidence: ev.confidence)
        }

        let votes = ModuleVotes(
            atlas: findVote("Atlas"),
            orion: findVote("Orion"),
            aether: findVote("Aether"),
            hermes: findVote("Hermes"),
            chiron: findVote("Chiron")
        )

        let conflicts = snapshot.conflicts.map { c in
            DecisionConflict(moduleA: c.moduleA, moduleB: c.moduleB, topic: c.topic, severity: 0.5)
        }

        return DecisionContext(
            decisionId: snapshot.id.uuidString,
            overallAction: snapshot.action.rawValue,
            dominantSignals: snapshot.dominantSignals,
            conflicts: conflicts,
            moduleVotes: votes
        )
    }

    func recordAttempt(symbol: String, action: TradeAction, price: Double, decisionTrace: DecisionTraceSnapshot, marketSnapshot: MarketSnapshot, blockReason: String, decisionSnapshot: DecisionSnapshot? = nil) {
        var dContext: DecisionContext? = nil
        if let ds = decisionSnapshot {
            dContext = makeDecisionContext(from: ds)
        }

        let attempt = Transaction(
            id: UUID(),
            type: .attempt,
            symbol: symbol,
            amount: 0,
            price: price,
            date: Date(),
            fee: 0,
            pnl: nil,
            pnlPercent: nil,
            decisionTrace: decisionTrace,
            marketSnapshot: marketSnapshot,
            positionSnapshot: nil,
            execution: nil,
            outcome: nil,
            schemaVersion: 2,
            source: "SYSTEM_GUARD",
            strategy: "UNKNOWN",
            reasonCode: blockReason,
            decisionContext: dContext,
            cooldownUntil: decisionSnapshot?.locks.cooldownUntil,
            minHoldUntil: decisionSnapshot?.locks.minHoldUntil,
            guardrailHit: true,
            guardrailReason: blockReason
        )
        PortfolioStore.shared.addTransaction(attempt)
    }
}
