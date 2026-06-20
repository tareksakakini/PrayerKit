//
//  PrayerTimeCalculator.swift
//  PrayerTimes
//
//  Created by Tarek Sakakini on 11/24/25.
//

import Foundation
import CoreLocation

// Calculation methods for prayer times
enum CalculationMethod: String, CaseIterable, Identifiable {
    case muslimWorldLeague = "Muslim World League"
    case egyptian = "Egyptian General Authority"
    case karachi = "University of Islamic Sciences, Karachi"
    case ummAlQura = "Umm Al-Qura University, Makkah"
    case dubai = "Dubai"
    case qatar = "Qatar"
    case kuwait = "Kuwait"
    case singapore = "Singapore"
    case northAmerica = "Islamic Society of North America (ISNA)"
    case turkey = "Diyanet İşleri (Turkey)"
    case tehran = "Institute of Geophysics, Tehran"
    case jafari = "Shia Ithna Ashari (Jafari)"
    case france = "Grande Mosquée de Paris"
    case morocco = "Moroccan Ministry of Habous"
    case russia = "Spiritual Administration of Muslims of Russia"

    var id: String { rawValue }

    // Fajr angle in degrees
    var fajrAngle: Double {
        switch self {
        case .muslimWorldLeague: return 18.0
        case .egyptian: return 19.5
        case .karachi: return 18.0
        case .ummAlQura: return 18.5
        case .dubai: return 18.2
        case .qatar: return 18.0
        case .kuwait: return 18.0
        case .singapore: return 20.0
        case .northAmerica: return 15.0
        case .turkey: return 18.0
        case .tehran: return 17.7
        case .jafari: return 16.0
        case .france: return 12.0
        case .morocco: return 19.0
        case .russia: return 16.0
        }
    }

    // Isha angle in degrees (negative means minutes after Maghrib)
    var ishaAngle: Double {
        switch self {
        case .muslimWorldLeague: return 17.0
        case .egyptian: return 17.5
        case .karachi: return 18.0
        case .ummAlQura: return 0.0 // 90 minutes after Maghrib
        case .dubai: return 18.2
        case .qatar: return 0.0 // 90 minutes after Maghrib
        case .kuwait: return 17.5
        case .singapore: return 18.0
        case .northAmerica: return 15.0
        case .turkey: return 17.0
        case .tehran: return 14.0
        case .jafari: return 14.0
        case .france: return 12.0
        case .morocco: return 17.0
        case .russia: return 15.0
        }
    }

    var ishaMinutesAfterMaghrib: Int? {
        switch self {
        case .ummAlQura, .qatar: return 90
        default: return nil
        }
    }

    /// Shia methods set Maghrib at a real solar depression angle (sun below
    /// the horizon) instead of at sunset. Sunni methods return nil → Maghrib = sunset.
    var maghribAngle: Double? {
        switch self {
        case .tehran: return 4.5
        case .jafari: return 4.0
        default: return nil
        }
    }
}

extension CalculationMethod {
    /// Maps an ISO 3166-1 alpha-2 country code to the calculation method most
    /// commonly used there. Returns nil for countries without a strong
    /// convention — callers should fall back to Muslim World League.
    static func recommended(forCountryCode code: String?) -> CalculationMethod? {
        guard let code = code?.uppercased() else { return nil }
        switch code {
        // North America
        case "US", "CA", "MX": return .northAmerica

        // Gulf
        case "SA": return .ummAlQura
        case "AE": return .dubai
        case "QA": return .qatar
        case "KW", "BH": return .kuwait

        // Egypt + Levant + Maghreb (excl. Morocco) + Sudan + Yemen
        case "EG", "SY", "LB", "JO", "PS", "IL", "IQ", "YE",
             "DZ", "TN", "LY", "SD", "MR": return .egyptian

        // South Asia
        case "PK", "IN", "BD", "AF", "LK", "NP", "BT", "MV": return .karachi

        // Country-specific
        case "TR": return .turkey
        case "IR": return .tehran
        case "FR": return .france
        case "MA": return .morocco

        // Russia + Central Asia + Caucasus
        case "RU", "KZ", "KG", "TJ", "UZ", "TM", "AZ": return .russia

        // SE Asia (MUIS-aligned 20°/18°)
        case "SG", "MY", "ID", "BN", "TH", "PH", "VN", "KH", "LA": return .singapore

        default: return nil
        }
    }
}

// Juristic method for Asr calculation
enum AsrJuristicMethod: String, CaseIterable, Identifiable {
    case shafi = "Shafi'i, Maliki, Hanbali"
    case hanafi = "Hanafi"
    
    var id: String { rawValue }
    
    var shadowFactor: Double {
        switch self {
        case .shafi: return 1.0
        case .hanafi: return 2.0
        }
    }
}

class PrayerTimeCalculator {
    
    private let calculationMethod: CalculationMethod
    private let asrMethod: AsrJuristicMethod
    
    init(calculationMethod: CalculationMethod = .muslimWorldLeague,
         asrMethod: AsrJuristicMethod = .shafi) {
        self.calculationMethod = calculationMethod
        self.asrMethod = asrMethod
    }
    
    func calculatePrayerTimes(for date: Date, at location: CLLocationCoordinate2D, timeZone: TimeZone? = nil) -> DailyPrayers {
        let effectiveTimeZone = timeZone ?? DateProvider.timeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = effectiveTimeZone
        let latitude = location.latitude
        let longitude = location.longitude

        // Calculate prayer times for this date and location
        let times = calculateTimes(for: date,
                                   latitude: latitude,
                                   longitude: longitude,
                                   timeZone: effectiveTimeZone)
        
        // Create Prayer objects
        var prayers: [Prayer] = []

        if let fajrTime = times.fajr {
            prayers.append(Prayer(name: .fajr, time: addHours(fajrTime, on: date, calendar: calendar)))
        }

        if let sunriseTime = times.sunrise {
            prayers.append(Prayer(name: .sunrise, time: addHours(sunriseTime, on: date, calendar: calendar)))
        }

        if let dhuhrTime = times.dhuhr {
            prayers.append(Prayer(name: .dhuhr, time: addHours(dhuhrTime, on: date, calendar: calendar)))
        }

        if let asrTime = times.asr {
            prayers.append(Prayer(name: .asr, time: addHours(asrTime, on: date, calendar: calendar)))
        }

        if let maghribTime = times.maghrib {
            prayers.append(Prayer(name: .maghrib, time: addHours(maghribTime, on: date, calendar: calendar)))
        }

        if let ishaTime = times.isha {
            prayers.append(Prayer(name: .isha, time: addHours(ishaTime, on: date, calendar: calendar)))
        }

        return DailyPrayers(date: date, prayers: prayers)
    }

    private func addHours(_ hours: Double, on date: Date, calendar: Calendar) -> Date {
        // Split hours into a day offset + intra-day seconds, then anchor at the
        // start of the target day in the calendar's time zone and add seconds.
        // Avoids `bySettingHour:direction:.forward`, which snaps to the next
        // occurrence — pushing post-midnight prayers (Fajr/Isha) to the wrong
        // day when "now" is already past their wall-clock time.
        let dayOffset = Int(floor(hours / 24.0))
        let normalizedHours = hours - (Double(dayOffset) * 24.0)
        let secondsIntoDay = normalizedHours * 3600.0

        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: date) ?? date
        let startOfTargetDay = calendar.startOfDay(for: targetDay)
        return startOfTargetDay.addingTimeInterval(secondsIntoDay)
    }
    
    private struct RawTimes {
        var fajr: Double?
        var sunrise: Double?
        var dhuhr: Double?
        var asr: Double?
        var maghrib: Double?
        var isha: Double?
    }
    
    private func calculateTimes(for date: Date,
                                latitude: Double,
                                longitude: Double,
                                timeZone: TimeZone) -> RawTimes {
        
        let timeZoneOffsetHours = Double(timeZone.secondsFromGMT(for: date)) / 3600.0

        // Julian century relative to J2000.0
        let julianDay = julianDay(for: date, timeZone: timeZone)
        let julianCentury = (julianDay - 2451545.0) / 36525.0
        
        let equationOfTimeMinutes = equationOfTime(julianCentury: julianCentury)
        let solarDeclination = sunDeclination(julianCentury: julianCentury)
        
        // Solar noon in hours
        let solarNoonMinutes = 720 - 4 * longitude - equationOfTimeMinutes + timeZoneOffsetHours * 60
        let dhuhr = solarNoonMinutes / 60.0
        
        // Helper to calculate hour angle for a given sun altitude
        let sunriseSunsetAngle = -0.833 // standard refraction and sun radius
        let sunrise = timeForAngle(angle: sunriseSunsetAngle,
                                   declination: solarDeclination,
                                   latitude: latitude,
                                   solarNoon: dhuhr,
                                   isMorning: true)
        let sunset = timeForAngle(angle: sunriseSunsetAngle,
                                  declination: solarDeclination,
                                  latitude: latitude,
                                  solarNoon: dhuhr,
                                  isMorning: false)
        
        let fajrAngle = timeForAngle(angle: -calculationMethod.fajrAngle,
                                     declination: solarDeclination,
                                     latitude: latitude,
                                     solarNoon: dhuhr,
                                     isMorning: true)

        // Shia methods set Maghrib at a real solar depression angle (sun
        // already past the horizon, ~15-20 min after sunset).
        let maghrib: Double?
        if let mAngle = calculationMethod.maghribAngle {
            maghrib = timeForAngle(angle: -mAngle,
                                   declination: solarDeclination,
                                   latitude: latitude,
                                   solarNoon: dhuhr,
                                   isMorning: false) ?? sunset
        } else {
            maghrib = sunset
        }

        let asrAngle = asrAltitudeAngle(declination: solarDeclination, latitude: latitude)
        let asr = timeForAngle(angle: asrAngle,
                               declination: solarDeclination,
                               latitude: latitude,
                               solarNoon: dhuhr,
                               isMorning: false)

        let ishaAngleTime: Double?
        let isFixedOffsetIsha: Bool
        if let minutes = calculationMethod.ishaMinutesAfterMaghrib, let maghrib = maghrib {
            ishaAngleTime = maghrib + Double(minutes) / 60.0
            isFixedOffsetIsha = true
        } else {
            ishaAngleTime = timeForAngle(angle: -calculationMethod.ishaAngle,
                                         declination: solarDeclination,
                                         latitude: latitude,
                                         solarNoon: dhuhr,
                                         isMorning: false)
            isFixedOffsetIsha = false
        }

        // High-latitude rule: angle-based.
        // Night is sunset → next day's sunrise (approximated as today's sunrise + 24h).
        // The night is split into a portion of `angle/60`, scaling per prayer so
        // steeper-angle methods (MWL 18°) get earlier Fajr / later Isha than
        // shallower ones (ISNA 15°). Acts as a clamp when the angle math returns
        // a valid time, and as the anchor when the sun never reaches the angle.
        // Matches Muslim Pro, PrayTimes.org, and IslamicFinder's behavior at high
        // latitudes. Fixed-offset Isha methods (Umm Al-Qura, Qatar) are exempt —
        // their Isha is defined relative to Maghrib, not an angle.
        let (fajr, isha) = applyAngleBasedHighLatitudeRule(
            fajrAngleTime: fajrAngle,
            ishaAngleTime: ishaAngleTime,
            sunrise: sunrise,
            sunset: sunset,
            isFixedOffsetIsha: isFixedOffsetIsha
        )

        return RawTimes(
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha
        )
    }

    private func applyAngleBasedHighLatitudeRule(
        fajrAngleTime: Double?,
        ishaAngleTime: Double?,
        sunrise: Double?,
        sunset: Double?,
        isFixedOffsetIsha: Bool
    ) -> (fajr: Double?, isha: Double?) {
        guard let sunrise, let sunset else {
            return (fajrAngleTime, ishaAngleTime)
        }

        let nightDuration = (sunrise + 24) - sunset
        let fajrPortion = nightDuration * calculationMethod.fajrAngle / 60.0
        let ishaPortion = nightDuration * calculationMethod.ishaAngle / 60.0
        let safeFajr = sunrise - fajrPortion
        let safeIsha = sunset + ishaPortion

        let fajr: Double?
        if let f = fajrAngleTime {
            fajr = max(f, safeFajr)
        } else {
            fajr = safeFajr
        }

        let isha: Double?
        if isFixedOffsetIsha {
            isha = ishaAngleTime
        } else if let i = ishaAngleTime {
            isha = min(i, safeIsha)
        } else {
            isha = safeIsha
        }

        return (fajr, isha)
    }
    
    private func julianDay(for date: Date, timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return 0
        }
        
        var y = year
        var m = month
        
        if m <= 2 {
            y -= 1
            m += 12
        }
        
        let a = floor(Double(y) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        
        let jd = floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1))
            + Double(day) + b - 1524.5
        
        return jd
    }
    
    private func sunDeclination(julianCentury: Double) -> Double {
        let obliquity = obliquityCorrection(julianCentury: julianCentury)
        let lambda = sunApparentLongitude(julianCentury: julianCentury)
        let obliquityRad = obliquity * .pi / 180
        let lambdaRad = lambda * .pi / 180
        
        return asin(sin(obliquityRad) * sin(lambdaRad)) * 180 / .pi
    }
    
    private func equationOfTime(julianCentury: Double) -> Double {
        let epsilon = obliquityCorrection(julianCentury: julianCentury)
        let l0 = meanLongitudeSun(julianCentury: julianCentury)
        let e = eccentricityEarthOrbit(julianCentury: julianCentury)
        let m = meanAnomalySun(julianCentury: julianCentury)
        
        let y = pow(tan((epsilon * .pi / 180) / 2), 2)
        let sin2L0 = sin(2 * l0 * .pi / 180)
        let sinM = sin(m * .pi / 180)
        let cos2L0 = cos(2 * l0 * .pi / 180)
        let sin4L0 = sin(4 * l0 * .pi / 180)
        let sin2M = sin(2 * m * .pi / 180)
        
        let eot = y * sin2L0 - 2 * e * sinM + 4 * e * y * sinM * cos2L0
            - 0.5 * y * y * sin4L0 - 1.25 * e * e * sin2M
        
        return eot * 4 * 180 / .pi // in minutes
    }
    
    private func meanLongitudeSun(julianCentury: Double) -> Double {
        let l0 = 280.46646 + julianCentury * (36000.76983 + julianCentury * 0.0003032)
        return l0.truncatingRemainder(dividingBy: 360)
    }
    
    private func meanAnomalySun(julianCentury: Double) -> Double {
        return 357.52911 + julianCentury * (35999.05029 - 0.0001537 * julianCentury)
    }
    
    private func eccentricityEarthOrbit(julianCentury: Double) -> Double {
        return 0.016708634 - julianCentury * (0.000042037 + 0.0000001267 * julianCentury)
    }
    
    private func sunApparentLongitude(julianCentury: Double) -> Double {
        let trueLongitude = sunTrueLongitude(julianCentury: julianCentury)
        let omega = 125.04 - 1934.136 * julianCentury
        return trueLongitude - 0.00569 - 0.00478 * sin(omega * .pi / 180)
    }
    
    private func sunTrueLongitude(julianCentury: Double) -> Double {
        let l0 = meanLongitudeSun(julianCentury: julianCentury)
        let c = sunEquationOfCenter(julianCentury: julianCentury)
        return l0 + c
    }
    
    private func sunEquationOfCenter(julianCentury: Double) -> Double {
        let m = meanAnomalySun(julianCentury: julianCentury)
        let mRad = m * .pi / 180
        return sin(mRad) * (1.914602 - julianCentury * (0.004817 + 0.000014 * julianCentury))
            + sin(2 * mRad) * (0.019993 - 0.000101 * julianCentury)
            + sin(3 * mRad) * 0.000289
    }
    
    private func obliquityCorrection(julianCentury: Double) -> Double {
        let e0 = 23 + (26 + ((21.448 - julianCentury * (46.815 + julianCentury * (0.00059 - julianCentury * 0.001813)))) / 60) / 60
        let omega = 125.04 - 1934.136 * julianCentury
        return e0 + 0.00256 * cos(omega * .pi / 180)
    }
    
    private func timeForAngle(angle: Double,
                              declination: Double,
                              latitude: Double,
                              solarNoon: Double,
                              isMorning: Bool) -> Double? {
        guard let hourAngle = hourAngle(angle: angle,
                                        declination: declination,
                                        latitude: latitude) else { return nil }
        return isMorning ? solarNoon - hourAngle : solarNoon + hourAngle
    }
    
    private func hourAngle(angle: Double, declination: Double, latitude: Double) -> Double? {
        let latRad = latitude * .pi / 180
        let decRad = declination * .pi / 180
        let angleRad = angle * .pi / 180
        
        let cosH = (sin(angleRad) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad))
        if cosH < -1 || cosH > 1 {
            return nil // Sun never reaches this angle
        }
        
        let h = acos(cosH) * 180 / .pi
        return h / 15.0
    }
    
    private func asrAltitudeAngle(declination: Double, latitude: Double) -> Double {
        let shadowFactor = asrMethod.shadowFactor
        let phiRad = latitude * .pi / 180
        let decRad = declination * .pi / 180
        
        // Sun altitude when shadow length reaches shadowFactor * object height
        let altitudeRad = atan(1.0 / (shadowFactor + tan(abs(phiRad - decRad))))
        return altitudeRad * 180 / .pi
    }
}
