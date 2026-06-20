//
//  PrayerTimeAPIComparisonTests.swift
//  PrayerKitTests
//
//  Validates our on-device prayer-time math against Aladhan's reference API
//  across the top 100 Islamic cities × the top 3 calculation methods used in
//  each country. A case passes when every prayer matches Aladhan within
//  10 minutes — the tolerance absorbs small refraction/EoT constant differences
//  and the per-minute rounding Aladhan applies to its published times.
//
//  Run:  cd PrayerTimesTests && swift test
//

import XCTest
import CoreLocation
@testable import PrayerKit

/// Write directly to stderr. The Swift Testing runner buffers `print()` per
/// test and only surfaces it on failure — stderr bypasses that so per-case
/// lines stream live during a passing run too.
private func emit(_ text: String) {
    if let data = (text + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

/// Fixed-width column padder. `String(format: "%-8@", ...)` doesn't work for
/// Swift strings — this gives reliably aligned cells.
private func pad(_ s: String, _ width: Int, alignRight: Bool = false) -> String {
    if s.count >= width { return String(s.prefix(width)) }
    let spaces = String(repeating: " ", count: width - s.count)
    return alignRight ? spaces + s : s + spaces
}

final class PrayerTimeAPIComparisonTests: XCTestCase {

    // MARK: - Configuration

    /// Maximum allowed per-prayer divergence vs the reference API, in minutes.
    private let toleranceMinutes: Int = 10

    /// Bounded concurrency for Aladhan calls. Anonymous traffic gets rate-
    /// limited around 100 req/burst, so 2 concurrent + 429-retry-with-backoff
    /// (in `AladhanClient`) is the pragmatic spot — fast enough to finish in
    /// a few minutes, slow enough not to hit the wall constantly.
    private let maxConcurrentRequests: Int = 2

    private let comparedPrayers: [PrayerName] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    /// Fixed reference date — summer solstice 2026. Reproducible across runs,
    /// and the solstice is where high-latitude edge cases bite hardest.
    private let referenceDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 20
        c.hour = 12; c.minute = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    // MARK: - Per-case result types

    private struct PrayerDiff {
        let prayer: PrayerName
        let local: Date?
        let api: Date?
        let diffMinutes: Int?  // nil when one side is missing
    }

    private struct CaseResult {
        let index: Int
        let total: Int
        let city: TestCity
        let choice: MethodChoice
        let diffs: [PrayerDiff]
        let outcome: Outcome

        enum Outcome {
            case passed(worst: Int)
            case failed(worst: Int, offenders: [(PrayerName, Int)])
            case skipped(reason: String)
        }
    }

    // MARK: - The single bulk test

    func test_AllCitiesAndMethods() async throws {
        // 1. Build the flat (city, method) work list.
        var cases: [(index: Int, city: TestCity, choice: MethodChoice)] = []
        for city in topIslamicCities {
            for choice in topMethods(forCountryCode: city.countryCode) {
                cases.append((cases.count + 1, city, choice))
            }
        }
        let total = cases.count

        emit("")
        emit("══════════════════════════════════════════════════════════════════════")
        emit("  Running \(total) cases — \(topIslamicCities.count) cities × top 3 methods each")
        emit("  Reference date: \(formatReferenceDate())  •  Tolerance: ≤ \(toleranceMinutes) min")
        emit("  Concurrency: \(maxConcurrentRequests)  •  Source of truth: api.aladhan.com")
        emit("══════════════════════════════════════════════════════════════════════")
        emit("")

        // 2. Run with bounded concurrency.
        var results: [CaseResult] = []
        results.reserveCapacity(total)

        try await withThrowingTaskGroup(of: CaseResult.self) { group in
            var iterator = cases.makeIterator()

            func enqueueNext() {
                guard let next = iterator.next() else { return }
                group.addTask { [weak self] in
                    guard let self else {
                        return CaseResult(index: next.index, total: total, city: next.city,
                                          choice: next.choice, diffs: [],
                                          outcome: .skipped(reason: "test instance gone"))
                    }
                    return await self.runOneCase(index: next.index, total: total,
                                                  city: next.city, choice: next.choice)
                }
            }

            for _ in 0..<maxConcurrentRequests { enqueueNext() }

            for try await result in group {
                results.append(result)
                enqueueNext()
            }
        }

        // 3. Sort and emit per-case lines (failures get a full table inline).
        results.sort { $0.index < $1.index }
        for r in results {
            emit(perCaseLine(r))
            if case .failed = r.outcome {
                emitFullTable(r)
            }
        }

        // 4. Final summary.
        emitSummary(results)

        // 5. Surface failures as a single XCTFail with the full list.
        let failures = results.compactMap { r -> String? in
            if case .failed(_, let offenders) = r.outcome {
                let parts = offenders.map { "\($0.0.rawValue) (\($0.1 >= 0 ? "+" : "")\($0.1)m)" }
                return "\(r.city.name), \(r.city.country) / \(r.choice.method.rawValue) — \(parts.joined(separator: ", "))"
            }
            return nil
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count) case(s) exceeded \(toleranceMinutes)-min tolerance:\n  " +
                    failures.joined(separator: "\n  "))
        }
    }

    // MARK: - Per-case runner

    private func runOneCase(
        index: Int, total: Int, city: TestCity, choice: MethodChoice
    ) async -> CaseResult {
        guard let timeZone = city.timeZone else {
            return CaseResult(index: index, total: total, city: city, choice: choice,
                              diffs: [], outcome: .skipped(reason: "Unknown timezone: \(city.timeZoneIdentifier)"))
        }

        // Fetch reference
        let api: AladhanClient.PrayerTimes
        do {
            api = try await AladhanClient.fetchPrayerTimes(
                date: referenceDate,
                latitude: city.latitude,
                longitude: city.longitude,
                aladhanMethodCode: choice.aladhanCode,
                asrMethodCode: 0,
                timeZone: timeZone
            )
        } catch {
            return CaseResult(index: index, total: total, city: city, choice: choice,
                              diffs: [], outcome: .skipped(reason: "API error: \(error)"))
        }

        // Compute locally
        let calculator = PrayerTimeCalculator(calculationMethod: choice.method, asrMethod: .shafi)
        let local = calculator.calculatePrayerTimes(for: referenceDate, at: city.coordinate, timeZone: timeZone)

        // Build per-prayer diffs
        var diffs: [PrayerDiff] = []
        var worst: Int = 0
        var offenders: [(PrayerName, Int)] = []

        for name in comparedPrayers {
            let localPrayer = local.prayers.first(where: { $0.name == name })
            let apiTime = api.times[name]

            switch (localPrayer, apiTime) {
            case (let l?, let a?):
                let diffMin = Int(round(l.time.timeIntervalSince(a) / 60))
                let abs = Swift.abs(diffMin)
                worst = max(worst, abs)
                if abs > toleranceMinutes { offenders.append((name, diffMin)) }
                diffs.append(.init(prayer: name, local: l.time, api: a, diffMinutes: diffMin))
            case (nil, let a?):
                offenders.append((name, 999))
                diffs.append(.init(prayer: name, local: nil, api: a, diffMinutes: nil))
            case (let l?, nil):
                offenders.append((name, 999))
                diffs.append(.init(prayer: name, local: l.time, api: nil, diffMinutes: nil))
            case (nil, nil):
                diffs.append(.init(prayer: name, local: nil, api: nil, diffMinutes: nil))
            }
        }

        let outcome: CaseResult.Outcome = offenders.isEmpty
            ? .passed(worst: worst)
            : .failed(worst: max(worst, offenders.map { Swift.abs($0.1) }.max() ?? 0), offenders: offenders)
        return CaseResult(index: index, total: total, city: city, choice: choice,
                          diffs: diffs, outcome: outcome)
    }

    // MARK: - Output formatting

    private func formatReferenceDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: referenceDate) + " (UTC)"
    }

    private func perCaseLine(_ r: CaseResult) -> String {
        let prefix = "[\(pad("\(r.index)", String(r.total).count, alignRight: true))/\(r.total)]"
        let cityLabel = pad("\(r.city.name), \(r.city.country)", 32)
        let methodLabel = pad(r.choice.method.rawValue, 38)
        switch r.outcome {
        case .passed(let worst):
            return "\(prefix) ✓  \(cityLabel) \(methodLabel)  worst \(pad("\(worst) min", 7, alignRight: true))"
        case .failed(let worst, let offenders):
            let summary = offenders.prefix(3)
                .map { "\($0.0.rawValue)(\($0.1 >= 0 ? "+" : "")\($0.1)m)" }
                .joined(separator: ", ")
            let extra = offenders.count > 3 ? ", +\(offenders.count - 3) more" : ""
            return "\(prefix) ✗  \(cityLabel) \(methodLabel)  worst \(pad("\(worst) min", 7, alignRight: true))   \(summary)\(extra)"
        case .skipped(let reason):
            return "\(prefix) ⚠️ \(cityLabel) \(methodLabel)  SKIPPED — \(reason)"
        }
    }

    private func emitFullTable(_ r: CaseResult) {
        guard let timeZone = r.city.timeZone else { return }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")

        emit("        ┌────────────┬───────┬───────┬─────────┐")
        emit("        │  Prayer    │ Local │  API  │  Diff   │")
        emit("        ├────────────┼───────┼───────┼─────────┤")
        for d in r.diffs {
            let marker: String
            let diffStr: String
            if let m = d.diffMinutes {
                marker = Swift.abs(m) > toleranceMinutes ? "✗" : "✓"
                diffStr = "\(m >= 0 ? "+" : "")\(m) min"
            } else if d.local == nil {
                marker = "✗"; diffStr = "NO LOCAL"
            } else {
                marker = "✗"; diffStr = "NO API"
            }
            let local = d.local.map { f.string(from: $0) } ?? " --- "
            let api = d.api.map { f.string(from: $0) } ?? " --- "
            emit("        │ \(marker) \(pad(d.prayer.rawValue, 8)) │ \(local) │ \(api) │ \(pad(diffStr, 7, alignRight: true)) │")
        }
        emit("        └────────────┴───────┴───────┴─────────┘")
    }

    private func emitSummary(_ results: [CaseResult]) {
        let passed = results.filter { if case .passed = $0.outcome { return true } else { return false } }
        let failed = results.filter { if case .failed = $0.outcome { return true } else { return false } }
        let skipped = results.filter { if case .skipped = $0.outcome { return true } else { return false } }

        let total = results.count
        let pctPassed = total > 0 ? Double(passed.count) / Double(total) * 100 : 0

        emit("")
        emit("══════════════════════════════════════════════════════════════════════")
        emit("  SUMMARY")
        emit("══════════════════════════════════════════════════════════════════════")
        emit("  Total cases:    \(total)")
        emit("  Passed:         \(passed.count)  (\(String(format: "%.1f", pctPassed))%)")
        emit("  Failed:         \(failed.count)")
        emit("  Skipped:        \(skipped.count)")
        emit("")

        // Worst diff per method (across all cities that ran it).
        var worstByMethod: [String: Int] = [:]
        var worstCaseByMethod: [String: String] = [:]
        for r in results {
            let worst: Int
            switch r.outcome {
            case .passed(let w): worst = w
            case .failed(let w, _): worst = w
            case .skipped: continue
            }
            let key = r.choice.method.rawValue
            if worst > (worstByMethod[key] ?? -1) {
                worstByMethod[key] = worst
                worstCaseByMethod[key] = "\(r.city.name), \(r.city.country)"
            }
        }
        if !worstByMethod.isEmpty {
            emit("  Worst diff by method:")
            let sorted = worstByMethod.sorted { $0.value > $1.value }
            for (method, worst) in sorted {
                let where_ = worstCaseByMethod[method] ?? ""
                emit("    \(pad(method, 40)) \(pad("\(worst) min", 7, alignRight: true))   \(where_)")
            }
            emit("")
        }

        if !failed.isEmpty {
            emit("  Failures:")
            for r in failed {
                if case .failed(_, let offenders) = r.outcome {
                    let summary = offenders
                        .map { "\($0.0.rawValue)(\($0.1 >= 0 ? "+" : "")\($0.1)m)" }
                        .joined(separator: ", ")
                    emit("    \(pad("\(r.city.name), \(r.city.country)", 32)) / \(pad(r.choice.method.rawValue, 38))  \(summary)")
                }
            }
            emit("")
        }

        if !skipped.isEmpty {
            emit("  Skipped:")
            for r in skipped {
                if case .skipped(let reason) = r.outcome {
                    emit("    \(pad("\(r.city.name), \(r.city.country)", 32)) / \(pad(r.choice.method.rawValue, 38))  \(reason)")
                }
            }
            emit("")
        }

        emit("══════════════════════════════════════════════════════════════════════")
    }
}
