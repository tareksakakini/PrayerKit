//
//  DebugCity.swift
//  PrayerTimes
//
//  A curated list of cities used by the debug location simulator.
//

import Foundation
import CoreLocation

struct DebugCity: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
    }

    var displayLabel: String {
        "\(name), \(country)"
    }
}

extension DebugCity {
    /// 50 cities chosen to cover every populated time zone plus a few
    /// high-latitude edge cases where prayer-time math typically breaks.
    static let top50: [DebugCity] = [
        // Middle East / Holy cities
        DebugCity(id: "mecca",      name: "Mecca",        country: "Saudi Arabia", countryCode: "SA", latitude: 21.4225,  longitude: 39.8262,   timeZoneIdentifier: "Asia/Riyadh"),
        DebugCity(id: "medina",     name: "Medina",       country: "Saudi Arabia", countryCode: "SA", latitude: 24.4539,  longitude: 39.6034,   timeZoneIdentifier: "Asia/Riyadh"),
        DebugCity(id: "riyadh",     name: "Riyadh",       country: "Saudi Arabia", countryCode: "SA", latitude: 24.7136,  longitude: 46.6753,   timeZoneIdentifier: "Asia/Riyadh"),
        DebugCity(id: "dubai",      name: "Dubai",        country: "UAE",          countryCode: "AE", latitude: 25.2048,  longitude: 55.2708,   timeZoneIdentifier: "Asia/Dubai"),
        DebugCity(id: "doha",       name: "Doha",         country: "Qatar",        countryCode: "QA", latitude: 25.2854,  longitude: 51.5310,   timeZoneIdentifier: "Asia/Qatar"),
        DebugCity(id: "kuwait",     name: "Kuwait City",  country: "Kuwait",       countryCode: "KW", latitude: 29.3759,  longitude: 47.9774,   timeZoneIdentifier: "Asia/Kuwait"),
        DebugCity(id: "tehran",     name: "Tehran",       country: "Iran",         countryCode: "IR", latitude: 35.6892,  longitude: 51.3890,   timeZoneIdentifier: "Asia/Tehran"),
        DebugCity(id: "baghdad",    name: "Baghdad",      country: "Iraq",         countryCode: "IQ", latitude: 33.3152,  longitude: 44.3661,   timeZoneIdentifier: "Asia/Baghdad"),
        DebugCity(id: "amman",      name: "Amman",        country: "Jordan",       countryCode: "JO", latitude: 31.9454,  longitude: 35.9284,   timeZoneIdentifier: "Asia/Amman"),
        DebugCity(id: "beirut",     name: "Beirut",       country: "Lebanon",      countryCode: "LB", latitude: 33.8938,  longitude: 35.5018,   timeZoneIdentifier: "Asia/Beirut"),
        DebugCity(id: "jerusalem",  name: "Jerusalem",    country: "Israel",       countryCode: "IL", latitude: 31.7683,  longitude: 35.2137,   timeZoneIdentifier: "Asia/Jerusalem"),

        // Africa
        DebugCity(id: "cairo",          name: "Cairo",        country: "Egypt",        countryCode: "EG", latitude: 30.0444,  longitude: 31.2357,   timeZoneIdentifier: "Africa/Cairo"),
        DebugCity(id: "casablanca",     name: "Casablanca",   country: "Morocco",      countryCode: "MA", latitude: 33.5731,  longitude: -7.5898,   timeZoneIdentifier: "Africa/Casablanca"),
        DebugCity(id: "lagos",          name: "Lagos",        country: "Nigeria",      countryCode: "NG", latitude: 6.5244,   longitude: 3.3792,    timeZoneIdentifier: "Africa/Lagos"),
        DebugCity(id: "nairobi",        name: "Nairobi",      country: "Kenya",        countryCode: "KE", latitude: -1.2921,  longitude: 36.8219,   timeZoneIdentifier: "Africa/Nairobi"),
        DebugCity(id: "capetown",       name: "Cape Town",    country: "South Africa", countryCode: "ZA", latitude: -33.9249, longitude: 18.4241,   timeZoneIdentifier: "Africa/Johannesburg"),

        // South / Southeast Asia
        DebugCity(id: "karachi",     name: "Karachi",      country: "Pakistan",     countryCode: "PK", latitude: 24.8607,  longitude: 67.0011,   timeZoneIdentifier: "Asia/Karachi"),
        DebugCity(id: "lahore",      name: "Lahore",       country: "Pakistan",     countryCode: "PK", latitude: 31.5204,  longitude: 74.3587,   timeZoneIdentifier: "Asia/Karachi"),
        DebugCity(id: "islamabad",   name: "Islamabad",    country: "Pakistan",     countryCode: "PK", latitude: 33.6844,  longitude: 73.0479,   timeZoneIdentifier: "Asia/Karachi"),
        DebugCity(id: "dhaka",       name: "Dhaka",        country: "Bangladesh",   countryCode: "BD", latitude: 23.8103,  longitude: 90.4125,   timeZoneIdentifier: "Asia/Dhaka"),
        DebugCity(id: "mumbai",      name: "Mumbai",       country: "India",        countryCode: "IN", latitude: 19.0760,  longitude: 72.8777,   timeZoneIdentifier: "Asia/Kolkata"),
        DebugCity(id: "newdelhi",    name: "New Delhi",    country: "India",        countryCode: "IN", latitude: 28.6139,  longitude: 77.2090,   timeZoneIdentifier: "Asia/Kolkata"),
        DebugCity(id: "jakarta",     name: "Jakarta",      country: "Indonesia",    countryCode: "ID", latitude: -6.2088,  longitude: 106.8456,  timeZoneIdentifier: "Asia/Jakarta"),
        DebugCity(id: "kualalumpur", name: "Kuala Lumpur", country: "Malaysia",     countryCode: "MY", latitude: 3.1390,   longitude: 101.6869,  timeZoneIdentifier: "Asia/Kuala_Lumpur"),
        DebugCity(id: "singapore",   name: "Singapore",    country: "Singapore",    countryCode: "SG", latitude: 1.3521,   longitude: 103.8198,  timeZoneIdentifier: "Asia/Singapore"),
        DebugCity(id: "manila",      name: "Manila",       country: "Philippines",  countryCode: "PH", latitude: 14.5995,  longitude: 120.9842,  timeZoneIdentifier: "Asia/Manila"),
        DebugCity(id: "bangkok",     name: "Bangkok",      country: "Thailand",     countryCode: "TH", latitude: 13.7563,  longitude: 100.5018,  timeZoneIdentifier: "Asia/Bangkok"),

        // East Asia / Pacific
        DebugCity(id: "hongkong",   name: "Hong Kong",    country: "Hong Kong",    countryCode: "HK", latitude: 22.3193,  longitude: 114.1694,  timeZoneIdentifier: "Asia/Hong_Kong"),
        DebugCity(id: "shanghai",   name: "Shanghai",     country: "China",        countryCode: "CN", latitude: 31.2304,  longitude: 121.4737,  timeZoneIdentifier: "Asia/Shanghai"),
        DebugCity(id: "beijing",    name: "Beijing",      country: "China",        countryCode: "CN", latitude: 39.9042,  longitude: 116.4074,  timeZoneIdentifier: "Asia/Shanghai"),
        DebugCity(id: "seoul",      name: "Seoul",        country: "South Korea",  countryCode: "KR", latitude: 37.5665,  longitude: 126.9780,  timeZoneIdentifier: "Asia/Seoul"),
        DebugCity(id: "tokyo",      name: "Tokyo",        country: "Japan",        countryCode: "JP", latitude: 35.6762,  longitude: 139.6503,  timeZoneIdentifier: "Asia/Tokyo"),
        DebugCity(id: "sydney",     name: "Sydney",       country: "Australia",    countryCode: "AU", latitude: -33.8688, longitude: 151.2093,  timeZoneIdentifier: "Australia/Sydney"),
        DebugCity(id: "auckland",   name: "Auckland",     country: "New Zealand",  countryCode: "NZ", latitude: -36.8485, longitude: 174.7633,  timeZoneIdentifier: "Pacific/Auckland"),

        // Europe
        DebugCity(id: "london",   name: "London",  country: "UK",      countryCode: "GB", latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London"),
        DebugCity(id: "paris",    name: "Paris",   country: "France",  countryCode: "FR", latitude: 48.8566, longitude: 2.3522,  timeZoneIdentifier: "Europe/Paris"),
        DebugCity(id: "berlin",   name: "Berlin",  country: "Germany", countryCode: "DE", latitude: 52.5200, longitude: 13.4050, timeZoneIdentifier: "Europe/Berlin"),
        DebugCity(id: "madrid",   name: "Madrid",  country: "Spain",   countryCode: "ES", latitude: 40.4168, longitude: -3.7038, timeZoneIdentifier: "Europe/Madrid"),
        DebugCity(id: "rome",     name: "Rome",    country: "Italy",   countryCode: "IT", latitude: 41.9028, longitude: 12.4964, timeZoneIdentifier: "Europe/Rome"),
        DebugCity(id: "istanbul", name: "Istanbul", country: "Turkey", countryCode: "TR", latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        DebugCity(id: "moscow",   name: "Moscow",  country: "Russia",  countryCode: "RU", latitude: 55.7558, longitude: 37.6173, timeZoneIdentifier: "Europe/Moscow"),

        // Americas
        DebugCity(id: "newyork",      name: "New York",     country: "USA",       countryCode: "US", latitude: 40.7128,  longitude: -74.0060,  timeZoneIdentifier: "America/New_York"),
        DebugCity(id: "losangeles",   name: "Los Angeles",  country: "USA",       countryCode: "US", latitude: 34.0522,  longitude: -118.2437, timeZoneIdentifier: "America/Los_Angeles"),
        DebugCity(id: "toronto",      name: "Toronto",      country: "Canada",    countryCode: "CA", latitude: 43.6532,  longitude: -79.3832,  timeZoneIdentifier: "America/Toronto"),
        DebugCity(id: "mexicocity",   name: "Mexico City",  country: "Mexico",    countryCode: "MX", latitude: 19.4326,  longitude: -99.1332,  timeZoneIdentifier: "America/Mexico_City"),
        DebugCity(id: "saopaulo",     name: "São Paulo",    country: "Brazil",    countryCode: "BR", latitude: -23.5505, longitude: -46.6333,  timeZoneIdentifier: "America/Sao_Paulo"),
        DebugCity(id: "buenosaires",  name: "Buenos Aires", country: "Argentina", countryCode: "AR", latitude: -34.6037, longitude: -58.3816,  timeZoneIdentifier: "America/Argentina/Buenos_Aires"),
        DebugCity(id: "honolulu",     name: "Honolulu",     country: "USA",       countryCode: "US", latitude: 21.3099,  longitude: -157.8581, timeZoneIdentifier: "Pacific/Honolulu"),

        // High-latitude edge cases for prayer-time math
        DebugCity(id: "reykjavik", name: "Reykjavik", country: "Iceland", countryCode: "IS", latitude: 64.1466, longitude: -21.9426, timeZoneIdentifier: "Atlantic/Reykjavik"),
        DebugCity(id: "tromso",    name: "Tromsø",    country: "Norway",  countryCode: "NO", latitude: 69.6492, longitude: 18.9553,  timeZoneIdentifier: "Europe/Oslo"),
    ]

    static func city(withID id: String) -> DebugCity? {
        top50.first { $0.id == id }
    }
}
