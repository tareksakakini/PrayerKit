//
//  AladhanClient.swift
//  PrayerKitTests
//
//  Thin async client for api.aladhan.com — the de-facto reference API for
//  prayer-time calculations. Tests use it as the source of truth.
//

import Foundation
@testable import PrayerKit

struct AladhanClient {
    static let baseURL = "https://api.aladhan.com/v1"

    /// Result of one /timings call: prayer name → absolute Date, with the
    /// timezone we resolved the response into and the URL we hit (for logging).
    struct PrayerTimes {
        let times: [PrayerName: Date]
        let timeZone: TimeZone
        let requestURL: URL
    }

    enum APIError: Error, CustomStringConvertible {
        case badURL
        case rateLimitExceeded(retryAfter: TimeInterval?)
        case httpFailure(status: Int, body: String)
        case decodingFailure(underlying: Error, body: String)
        case missingTiming(name: String)
        case invalidTimingFormat(name: String, raw: String)

        var description: String {
            switch self {
            case .badURL:
                return "Could not construct request URL"
            case .rateLimitExceeded(let retryAfter):
                return "Rate limit exceeded (retry-after: \(retryAfter.map { "\(Int($0))s" } ?? "unknown"))"
            case .httpFailure(let status, let body):
                return "HTTP \(status): \(body.prefix(200))"
            case .decodingFailure(let underlying, let body):
                return "JSON decoding failed (\(underlying)). Body: \(body.prefix(200))"
            case .missingTiming(let name):
                return "Response missing prayer: \(name)"
            case .invalidTimingFormat(let name, let raw):
                return "Could not parse \(name) time: '\(raw)'"
            }
        }
    }

    /// Aladhan rate-limits anonymous traffic. Retries 429 responses with an
    /// escalating backoff so a long bulk run completes instead of failing
    /// every case once the limit is hit.
    static func fetchPrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        aladhanMethodCode: Int,
        asrMethodCode: Int,
        timeZone: TimeZone
    ) async throws -> PrayerTimes {
        let backoffsSeconds: [Double] = [5, 15, 30, 60, 90]
        var attempt = 0
        while true {
            do {
                return try await performFetch(
                    date: date, latitude: latitude, longitude: longitude,
                    aladhanMethodCode: aladhanMethodCode, asrMethodCode: asrMethodCode,
                    timeZone: timeZone
                )
            } catch APIError.rateLimitExceeded(let retryAfter) {
                guard attempt < backoffsSeconds.count else {
                    throw APIError.rateLimitExceeded(retryAfter: retryAfter)
                }
                let wait = retryAfter ?? backoffsSeconds[attempt]
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    private static func performFetch(
        date: Date,
        latitude: Double,
        longitude: Double,
        aladhanMethodCode: Int,
        asrMethodCode: Int,
        timeZone: TimeZone
    ) async throws -> PrayerTimes {
        // Aladhan's date path segment is in the *city's* local day. Format with
        // the target timezone, not UTC.
        let pathDateFormatter = DateFormatter()
        pathDateFormatter.dateFormat = "dd-MM-yyyy"
        pathDateFormatter.timeZone = timeZone
        pathDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateSegment = pathDateFormatter.string(from: date)

        var components = URLComponents(string: "\(baseURL)/timings/\(dateSegment)")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "method", value: String(aladhanMethodCode)),
            URLQueryItem(name: "school", value: String(asrMethodCode)),
            // Pin the timezone so Aladhan doesn't try to resolve it from
            // coordinates (which can disagree near borders / DST cutovers).
            URLQueryItem(name: "timezonestring", value: timeZone.identifier),
        ]
        guard let url = components?.url else { throw APIError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let bodyString = String(data: data, encoding: .utf8) ?? ""

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                // Honor the server's Retry-After header when present
                // (numeric seconds, per RFC 7231).
                let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init)
                throw APIError.rateLimitExceeded(retryAfter: retryAfter)
            }
            if http.statusCode != 200 {
                throw APIError.httpFailure(status: http.statusCode, body: bodyString)
            }
        }

        let decoded: AladhanResponse
        do {
            decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        } catch {
            throw APIError.decodingFailure(underlying: error, body: bodyString)
        }

        // Parse "HH:mm" (sometimes "HH:mm (TZ)") for each prayer into an
        // absolute Date by combining with the date segment in the target TZ.
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "dd-MM-yyyy HH:mm"
        timeFormatter.timeZone = timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        let nameMap: [(jsonKey: String, prayer: PrayerName)] = [
            ("Fajr", .fajr),
            ("Sunrise", .sunrise),
            ("Dhuhr", .dhuhr),
            ("Asr", .asr),
            ("Maghrib", .maghrib),
            ("Isha", .isha),
        ]

        var times: [PrayerName: Date] = [:]
        for entry in nameMap {
            guard let raw = decoded.data.timings[entry.jsonKey] else {
                throw APIError.missingTiming(name: entry.jsonKey)
            }
            // Strip any trailing "(EDT)" / "(BST)" suffix Aladhan sometimes adds.
            let hhmm = String(raw.split(separator: " ").first ?? "")
            guard let parsed = timeFormatter.date(from: "\(dateSegment) \(hhmm)") else {
                throw APIError.invalidTimingFormat(name: entry.jsonKey, raw: raw)
            }
            times[entry.prayer] = parsed
        }

        return PrayerTimes(times: times, timeZone: timeZone, requestURL: url)
    }
}

// MARK: - Response shape

private struct AladhanResponse: Decodable {
    let code: Int
    let data: AladhanData
}

private struct AladhanData: Decodable {
    let timings: [String: String]
}
