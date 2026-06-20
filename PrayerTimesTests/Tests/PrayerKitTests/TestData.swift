//
//  TestData.swift
//  PrayerKitTests
//
//  100 Islamic cities + the top-3 calculation methods used in each country.
//  Drives the bulk API-comparison test.
//

import Foundation
import CoreLocation
@testable import PrayerKit

struct TestCity {
    let name: String
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }
}

struct MethodChoice {
    let method: CalculationMethod
    /// Aladhan API method code. Reference: https://aladhan.com/calculation-methods
    let aladhanCode: Int
}

// MARK: - The 100 cities

/// Curated for total Muslim population, religious significance, and geographic
/// coverage. Cities sharing a country share a method ranking (see `topMethods`).
let topIslamicCities: [TestCity] = [
    // Saudi Arabia (incl. holy cities)
    TestCity(name: "Mecca",     country: "Saudi Arabia", countryCode: "SA", latitude: 21.4225, longitude: 39.8262, timeZoneIdentifier: "Asia/Riyadh"),
    TestCity(name: "Medina",    country: "Saudi Arabia", countryCode: "SA", latitude: 24.4539, longitude: 39.6034, timeZoneIdentifier: "Asia/Riyadh"),
    TestCity(name: "Riyadh",    country: "Saudi Arabia", countryCode: "SA", latitude: 24.7136, longitude: 46.6753, timeZoneIdentifier: "Asia/Riyadh"),
    TestCity(name: "Jeddah",    country: "Saudi Arabia", countryCode: "SA", latitude: 21.4858, longitude: 39.1925, timeZoneIdentifier: "Asia/Riyadh"),
    TestCity(name: "Dammam",    country: "Saudi Arabia", countryCode: "SA", latitude: 26.4207, longitude: 50.0888, timeZoneIdentifier: "Asia/Riyadh"),

    // Gulf
    TestCity(name: "Dubai",     country: "UAE",     countryCode: "AE", latitude: 25.2048, longitude: 55.2708, timeZoneIdentifier: "Asia/Dubai"),
    TestCity(name: "Abu Dhabi", country: "UAE",     countryCode: "AE", latitude: 24.4539, longitude: 54.3773, timeZoneIdentifier: "Asia/Dubai"),
    TestCity(name: "Sharjah",   country: "UAE",     countryCode: "AE", latitude: 25.3463, longitude: 55.4209, timeZoneIdentifier: "Asia/Dubai"),
    TestCity(name: "Doha",      country: "Qatar",   countryCode: "QA", latitude: 25.2854, longitude: 51.5310, timeZoneIdentifier: "Asia/Qatar"),
    TestCity(name: "Kuwait City", country: "Kuwait", countryCode: "KW", latitude: 29.3759, longitude: 47.9774, timeZoneIdentifier: "Asia/Kuwait"),
    TestCity(name: "Manama",    country: "Bahrain", countryCode: "BH", latitude: 26.2285, longitude: 50.5860, timeZoneIdentifier: "Asia/Bahrain"),
    TestCity(name: "Muscat",    country: "Oman",    countryCode: "OM", latitude: 23.5859, longitude: 58.4059, timeZoneIdentifier: "Asia/Muscat"),

    // Iran (Shia)
    TestCity(name: "Tehran",    country: "Iran", countryCode: "IR", latitude: 35.6892, longitude: 51.3890, timeZoneIdentifier: "Asia/Tehran"),
    TestCity(name: "Mashhad",   country: "Iran", countryCode: "IR", latitude: 36.2605, longitude: 59.6168, timeZoneIdentifier: "Asia/Tehran"),
    TestCity(name: "Isfahan",   country: "Iran", countryCode: "IR", latitude: 32.6539, longitude: 51.6660, timeZoneIdentifier: "Asia/Tehran"),
    TestCity(name: "Shiraz",    country: "Iran", countryCode: "IR", latitude: 29.5916, longitude: 52.5836, timeZoneIdentifier: "Asia/Tehran"),
    TestCity(name: "Tabriz",    country: "Iran", countryCode: "IR", latitude: 38.0962, longitude: 46.2738, timeZoneIdentifier: "Asia/Tehran"),
    TestCity(name: "Qom",       country: "Iran", countryCode: "IR", latitude: 34.6416, longitude: 50.8746, timeZoneIdentifier: "Asia/Tehran"),

    // Iraq (mixed Sunni/Shia; Najaf + Karbala are Shia holy)
    TestCity(name: "Baghdad",   country: "Iraq", countryCode: "IQ", latitude: 33.3152, longitude: 44.3661, timeZoneIdentifier: "Asia/Baghdad"),
    TestCity(name: "Basra",     country: "Iraq", countryCode: "IQ", latitude: 30.5081, longitude: 47.7804, timeZoneIdentifier: "Asia/Baghdad"),
    TestCity(name: "Mosul",     country: "Iraq", countryCode: "IQ", latitude: 36.3400, longitude: 43.1300, timeZoneIdentifier: "Asia/Baghdad"),
    TestCity(name: "Najaf",     country: "Iraq", countryCode: "IQ", latitude: 32.0000, longitude: 44.3334, timeZoneIdentifier: "Asia/Baghdad"),
    TestCity(name: "Karbala",   country: "Iraq", countryCode: "IQ", latitude: 32.6160, longitude: 44.0240, timeZoneIdentifier: "Asia/Baghdad"),
    TestCity(name: "Erbil",     country: "Iraq", countryCode: "IQ", latitude: 36.1900, longitude: 44.0093, timeZoneIdentifier: "Asia/Baghdad"),

    // Levant
    TestCity(name: "Damascus",  country: "Syria",   countryCode: "SY", latitude: 33.5138, longitude: 36.2765, timeZoneIdentifier: "Asia/Damascus"),
    TestCity(name: "Aleppo",    country: "Syria",   countryCode: "SY", latitude: 36.2021, longitude: 37.1343, timeZoneIdentifier: "Asia/Damascus"),
    TestCity(name: "Homs",      country: "Syria",   countryCode: "SY", latitude: 34.7268, longitude: 36.7234, timeZoneIdentifier: "Asia/Damascus"),
    TestCity(name: "Amman",     country: "Jordan",  countryCode: "JO", latitude: 31.9454, longitude: 35.9284, timeZoneIdentifier: "Asia/Amman"),
    TestCity(name: "Zarqa",     country: "Jordan",  countryCode: "JO", latitude: 32.0728, longitude: 36.0876, timeZoneIdentifier: "Asia/Amman"),
    TestCity(name: "Beirut",    country: "Lebanon", countryCode: "LB", latitude: 33.8938, longitude: 35.5018, timeZoneIdentifier: "Asia/Beirut"),
    TestCity(name: "Tripoli",   country: "Lebanon", countryCode: "LB", latitude: 34.4332, longitude: 35.8497, timeZoneIdentifier: "Asia/Beirut"),
    TestCity(name: "Jerusalem", country: "Israel",  countryCode: "IL", latitude: 31.7683, longitude: 35.2137, timeZoneIdentifier: "Asia/Jerusalem"),
    TestCity(name: "Gaza",      country: "Palestine", countryCode: "PS", latitude: 31.5017, longitude: 34.4668, timeZoneIdentifier: "Asia/Hebron"),

    // Yemen
    TestCity(name: "Sanaa",     country: "Yemen", countryCode: "YE", latitude: 15.3694, longitude: 44.1910, timeZoneIdentifier: "Asia/Aden"),
    TestCity(name: "Aden",      country: "Yemen", countryCode: "YE", latitude: 12.7855, longitude: 45.0187, timeZoneIdentifier: "Asia/Aden"),

    // Egypt
    TestCity(name: "Cairo",       country: "Egypt", countryCode: "EG", latitude: 30.0444, longitude: 31.2357, timeZoneIdentifier: "Africa/Cairo"),
    TestCity(name: "Alexandria",  country: "Egypt", countryCode: "EG", latitude: 31.2001, longitude: 29.9187, timeZoneIdentifier: "Africa/Cairo"),
    TestCity(name: "Giza",        country: "Egypt", countryCode: "EG", latitude: 30.0131, longitude: 31.2089, timeZoneIdentifier: "Africa/Cairo"),
    TestCity(name: "Asyut",       country: "Egypt", countryCode: "EG", latitude: 27.1809, longitude: 31.1837, timeZoneIdentifier: "Africa/Cairo"),

    // Sudan
    TestCity(name: "Khartoum",   country: "Sudan", countryCode: "SD", latitude: 15.5007, longitude: 32.5599, timeZoneIdentifier: "Africa/Khartoum"),
    TestCity(name: "Omdurman",   country: "Sudan", countryCode: "SD", latitude: 15.6445, longitude: 32.4777, timeZoneIdentifier: "Africa/Khartoum"),

    // North Africa
    TestCity(name: "Tripoli",     country: "Libya",    countryCode: "LY", latitude: 32.8872, longitude: 13.1913, timeZoneIdentifier: "Africa/Tripoli"),
    TestCity(name: "Benghazi",    country: "Libya",    countryCode: "LY", latitude: 32.1167, longitude: 20.0667, timeZoneIdentifier: "Africa/Tripoli"),
    TestCity(name: "Tunis",       country: "Tunisia",  countryCode: "TN", latitude: 36.8065, longitude: 10.1815, timeZoneIdentifier: "Africa/Tunis"),
    TestCity(name: "Algiers",     country: "Algeria",  countryCode: "DZ", latitude: 36.7538, longitude: 3.0588,  timeZoneIdentifier: "Africa/Algiers"),
    TestCity(name: "Oran",        country: "Algeria",  countryCode: "DZ", latitude: 35.6911, longitude: -0.6417, timeZoneIdentifier: "Africa/Algiers"),
    TestCity(name: "Constantine", country: "Algeria",  countryCode: "DZ", latitude: 36.3650, longitude: 6.6147,  timeZoneIdentifier: "Africa/Algiers"),
    TestCity(name: "Casablanca",  country: "Morocco",  countryCode: "MA", latitude: 33.5731, longitude: -7.5898, timeZoneIdentifier: "Africa/Casablanca"),
    TestCity(name: "Rabat",       country: "Morocco",  countryCode: "MA", latitude: 34.0209, longitude: -6.8416, timeZoneIdentifier: "Africa/Casablanca"),
    TestCity(name: "Marrakesh",   country: "Morocco",  countryCode: "MA", latitude: 31.6295, longitude: -7.9811, timeZoneIdentifier: "Africa/Casablanca"),
    TestCity(name: "Fez",         country: "Morocco",  countryCode: "MA", latitude: 34.0181, longitude: -5.0078, timeZoneIdentifier: "Africa/Casablanca"),

    // West / Sub-Saharan Africa
    TestCity(name: "Nouakchott", country: "Mauritania", countryCode: "MR", latitude: 18.0858, longitude: -15.9785, timeZoneIdentifier: "Africa/Nouakchott"),
    TestCity(name: "Dakar",      country: "Senegal",    countryCode: "SN", latitude: 14.6928, longitude: -17.4467, timeZoneIdentifier: "Africa/Dakar"),
    TestCity(name: "Bamako",     country: "Mali",       countryCode: "ML", latitude: 12.6392, longitude: -8.0029,  timeZoneIdentifier: "Africa/Bamako"),
    TestCity(name: "Lagos",      country: "Nigeria",    countryCode: "NG", latitude: 6.5244,  longitude: 3.3792,   timeZoneIdentifier: "Africa/Lagos"),
    TestCity(name: "Kano",       country: "Nigeria",    countryCode: "NG", latitude: 12.0022, longitude: 8.5919,   timeZoneIdentifier: "Africa/Lagos"),
    TestCity(name: "Abuja",      country: "Nigeria",    countryCode: "NG", latitude: 9.0765,  longitude: 7.3986,   timeZoneIdentifier: "Africa/Lagos"),
    TestCity(name: "Mogadishu",  country: "Somalia",    countryCode: "SO", latitude: 2.0469,  longitude: 45.3182,  timeZoneIdentifier: "Africa/Mogadishu"),

    // Turkey
    TestCity(name: "Istanbul",  country: "Turkey", countryCode: "TR", latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
    TestCity(name: "Ankara",    country: "Turkey", countryCode: "TR", latitude: 39.9334, longitude: 32.8597, timeZoneIdentifier: "Europe/Istanbul"),
    TestCity(name: "Izmir",     country: "Turkey", countryCode: "TR", latitude: 38.4192, longitude: 27.1287, timeZoneIdentifier: "Europe/Istanbul"),
    TestCity(name: "Bursa",     country: "Turkey", countryCode: "TR", latitude: 40.1885, longitude: 29.0610, timeZoneIdentifier: "Europe/Istanbul"),
    TestCity(name: "Antalya",   country: "Turkey", countryCode: "TR", latitude: 36.8969, longitude: 30.7133, timeZoneIdentifier: "Europe/Istanbul"),

    // Pakistan
    TestCity(name: "Karachi",    country: "Pakistan", countryCode: "PK", latitude: 24.8607, longitude: 67.0011, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Lahore",     country: "Pakistan", countryCode: "PK", latitude: 31.5204, longitude: 74.3587, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Islamabad",  country: "Pakistan", countryCode: "PK", latitude: 33.6844, longitude: 73.0479, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Faisalabad", country: "Pakistan", countryCode: "PK", latitude: 31.4504, longitude: 73.1350, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Rawalpindi", country: "Pakistan", countryCode: "PK", latitude: 33.5973, longitude: 73.0479, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Multan",     country: "Pakistan", countryCode: "PK", latitude: 30.1575, longitude: 71.5249, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Peshawar",   country: "Pakistan", countryCode: "PK", latitude: 34.0151, longitude: 71.5805, timeZoneIdentifier: "Asia/Karachi"),
    TestCity(name: "Quetta",     country: "Pakistan", countryCode: "PK", latitude: 30.1798, longitude: 66.9750, timeZoneIdentifier: "Asia/Karachi"),

    // India
    TestCity(name: "Mumbai",    country: "India", countryCode: "IN", latitude: 19.0760, longitude: 72.8777, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Delhi",     country: "India", countryCode: "IN", latitude: 28.6139, longitude: 77.2090, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Kolkata",   country: "India", countryCode: "IN", latitude: 22.5726, longitude: 88.3639, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Hyderabad", country: "India", countryCode: "IN", latitude: 17.3850, longitude: 78.4867, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Bangalore", country: "India", countryCode: "IN", latitude: 12.9716, longitude: 77.5946, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Lucknow",   country: "India", countryCode: "IN", latitude: 26.8467, longitude: 80.9462, timeZoneIdentifier: "Asia/Kolkata"),
    TestCity(name: "Ahmedabad", country: "India", countryCode: "IN", latitude: 23.0225, longitude: 72.5714, timeZoneIdentifier: "Asia/Kolkata"),

    // Bangladesh
    TestCity(name: "Dhaka",      country: "Bangladesh", countryCode: "BD", latitude: 23.8103, longitude: 90.4125, timeZoneIdentifier: "Asia/Dhaka"),
    TestCity(name: "Chittagong", country: "Bangladesh", countryCode: "BD", latitude: 22.3569, longitude: 91.7832, timeZoneIdentifier: "Asia/Dhaka"),
    TestCity(name: "Sylhet",     country: "Bangladesh", countryCode: "BD", latitude: 24.8949, longitude: 91.8687, timeZoneIdentifier: "Asia/Dhaka"),
    TestCity(name: "Khulna",     country: "Bangladesh", countryCode: "BD", latitude: 22.8456, longitude: 89.5403, timeZoneIdentifier: "Asia/Dhaka"),

    // Afghanistan / Central Asia
    TestCity(name: "Kabul",     country: "Afghanistan", countryCode: "AF", latitude: 34.5553, longitude: 69.2075, timeZoneIdentifier: "Asia/Kabul"),
    TestCity(name: "Tashkent",  country: "Uzbekistan",  countryCode: "UZ", latitude: 41.2995, longitude: 69.2401, timeZoneIdentifier: "Asia/Tashkent"),
    TestCity(name: "Almaty",    country: "Kazakhstan",  countryCode: "KZ", latitude: 43.2220, longitude: 76.8512, timeZoneIdentifier: "Asia/Almaty"),
    TestCity(name: "Baku",      country: "Azerbaijan",  countryCode: "AZ", latitude: 40.4093, longitude: 49.8671, timeZoneIdentifier: "Asia/Baku"),

    // Russia + Balkans
    TestCity(name: "Moscow",    country: "Russia",                 countryCode: "RU", latitude: 55.7558, longitude: 37.6173, timeZoneIdentifier: "Europe/Moscow"),
    TestCity(name: "Kazan",     country: "Russia",                 countryCode: "RU", latitude: 55.8304, longitude: 49.0661, timeZoneIdentifier: "Europe/Moscow"),
    TestCity(name: "Sarajevo",  country: "Bosnia and Herzegovina", countryCode: "BA", latitude: 43.8563, longitude: 18.4131, timeZoneIdentifier: "Europe/Sarajevo"),

    // Southeast Asia
    TestCity(name: "Jakarta",   country: "Indonesia", countryCode: "ID", latitude: -6.2088, longitude: 106.8456, timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Surabaya",  country: "Indonesia", countryCode: "ID", latitude: -7.2575, longitude: 112.7521, timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Bandung",   country: "Indonesia", countryCode: "ID", latitude: -6.9175, longitude: 107.6191, timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Medan",     country: "Indonesia", countryCode: "ID", latitude: 3.5952,  longitude: 98.6722,  timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Semarang",  country: "Indonesia", countryCode: "ID", latitude: -6.9667, longitude: 110.4167, timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Makassar",  country: "Indonesia", countryCode: "ID", latitude: -5.1477, longitude: 119.4327, timeZoneIdentifier: "Asia/Makassar"),
    TestCity(name: "Palembang", country: "Indonesia", countryCode: "ID", latitude: -2.9761, longitude: 104.7754, timeZoneIdentifier: "Asia/Jakarta"),
    TestCity(name: "Kuala Lumpur",        country: "Malaysia",  countryCode: "MY", latitude: 3.1390, longitude: 101.6869, timeZoneIdentifier: "Asia/Kuala_Lumpur"),
    TestCity(name: "Johor Bahru",         country: "Malaysia",  countryCode: "MY", latitude: 1.4927, longitude: 103.7414, timeZoneIdentifier: "Asia/Kuala_Lumpur"),
    TestCity(name: "Singapore",           country: "Singapore", countryCode: "SG", latitude: 1.3521, longitude: 103.8198, timeZoneIdentifier: "Asia/Singapore"),
    TestCity(name: "Bandar Seri Begawan", country: "Brunei",    countryCode: "BN", latitude: 4.9036, longitude: 114.9398, timeZoneIdentifier: "Asia/Brunei"),
]

// MARK: - Method ranking per country

/// Top 3 calculation methods commonly used in each country (in order).
/// Default fallback (no entry) is MWL → Egyptian → Umm Al-Qura, which is what
/// most apps use for countries without a strong regional convention.
func topMethods(forCountryCode code: String) -> [MethodChoice] {
    // Aladhan method codes (https://aladhan.com/calculation-methods):
    //   0 Jafari    1 Karachi   2 ISNA     3 MWL     4 Umm Al-Qura
    //   5 Egyptian  7 Tehran    9 Kuwait  10 Qatar  11 MUIS Singapore
    //   12 UOIF Fr  13 Diyanet  14 Russia 16 Dubai  21 Morocco
    switch code.uppercased() {

    // Gulf
    case "SA":
        return [.init(method: .ummAlQura, aladhanCode: 4),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5)]
    case "AE":
        return [.init(method: .dubai, aladhanCode: 16),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .ummAlQura, aladhanCode: 4)]
    case "QA":
        return [.init(method: .qatar, aladhanCode: 10),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .ummAlQura, aladhanCode: 4)]
    case "KW", "BH":
        return [.init(method: .kuwait, aladhanCode: 9),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .ummAlQura, aladhanCode: 4)]
    case "OM":
        return [.init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5),
                .init(method: .ummAlQura, aladhanCode: 4)]

    // Shia-majority — Jafari/Tehran on top
    case "IR":
        return [.init(method: .tehran, aladhanCode: 7),
                .init(method: .jafari, aladhanCode: 0),
                .init(method: .muslimWorldLeague, aladhanCode: 3)]
    case "IQ":
        return [.init(method: .karachi, aladhanCode: 1),
                .init(method: .jafari, aladhanCode: 0),
                .init(method: .muslimWorldLeague, aladhanCode: 3)]
    case "AZ":
        return [.init(method: .russia, aladhanCode: 14),
                .init(method: .jafari, aladhanCode: 0),
                .init(method: .muslimWorldLeague, aladhanCode: 3)]

    // Levant + Egypt + N. Africa (excl. Morocco/Turkey)
    case "EG", "SY", "LB", "JO", "PS", "IL", "YE", "DZ", "TN", "LY", "SD", "MR":
        return [.init(method: .egyptian, aladhanCode: 5),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .ummAlQura, aladhanCode: 4)]

    // South Asia + Afghanistan
    case "PK", "IN", "BD", "AF":
        return [.init(method: .karachi, aladhanCode: 1),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .ummAlQura, aladhanCode: 4)]

    // Turkey
    case "TR":
        return [.init(method: .turkey, aladhanCode: 13),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5)]

    // Morocco
    case "MA":
        return [.init(method: .morocco, aladhanCode: 21),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5)]

    // SE Asia (20°/18° methods)
    case "ID", "MY", "SG", "BN":
        return [.init(method: .singapore, aladhanCode: 11),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5)]

    // Russia + Central Asia
    case "RU", "KZ", "KG", "TJ", "UZ", "TM":
        return [.init(method: .russia, aladhanCode: 14),
                .init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5)]

    // Sub-Saharan Africa + Balkans (fall back to MWL)
    case "SN", "ML", "NG", "SO", "BA":
        return [.init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5),
                .init(method: .ummAlQura, aladhanCode: 4)]

    default:
        return [.init(method: .muslimWorldLeague, aladhanCode: 3),
                .init(method: .egyptian, aladhanCode: 5),
                .init(method: .ummAlQura, aladhanCode: 4)]
    }
}
