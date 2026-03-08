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
        }
    }
    
    var ishaMinutesAfterMaghrib: Int? {
        switch self {
        case .ummAlQura, .qatar: return 90
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
    
    func calculatePrayerTimes(for date: Date, at location: CLLocationCoordinate2D) -> DailyPrayers {
        let calendar = Calendar.current
        let latitude = location.latitude
        let longitude = location.longitude
        let timeZone = TimeZone.current
        
        // Calculate prayer times for this date and location
        let times = calculateTimes(for: date,
                                   latitude: latitude,
                                   longitude: longitude,
                                   timeZone: timeZone)
        
        // Create Prayer objects
        var prayers: [Prayer] = []
        
        let baseDate = calendar.startOfDay(for: date)
        
        if let fajrTime = times.fajr {
            prayers.append(Prayer(name: .fajr, time: addHours(fajrTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        if let sunriseTime = times.sunrise {
            prayers.append(Prayer(name: .sunrise, time: addHours(sunriseTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        if let dhuhrTime = times.dhuhr {
            prayers.append(Prayer(name: .dhuhr, time: addHours(dhuhrTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        if let asrTime = times.asr {
            prayers.append(Prayer(name: .asr, time: addHours(asrTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        if let maghribTime = times.maghrib {
            prayers.append(Prayer(name: .maghrib, time: addHours(maghribTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        if let ishaTime = times.isha {
            prayers.append(Prayer(name: .isha, time: addHours(ishaTime, on: date, calendar: calendar, fallbackDate: baseDate)))
        }
        
        return DailyPrayers(date: date, prayers: prayers)
    }
    
    private func addHours(_ hours: Double, on date: Date, calendar: Calendar, fallbackDate: Date) -> Date {
        let dayOffset = Int(floor(hours / 24.0))
        let normalizedHours = hours - (Double(dayOffset) * 24.0)
        let hour = Int(floor(normalizedHours))
        let minuteFraction = (normalizedHours - Double(hour)) * 60.0
        let minute = Int(floor(minuteFraction))
        let second = min(59, max(0, Int(round((minuteFraction - Double(minute)) * 60.0))))
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: date) ?? date
        
        if let localWallClockDate = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: targetDay,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ) {
            return localWallClockDate
        }
        
        // Fallback to interval arithmetic if local wall-clock construction fails.
        return fallbackDate.addingTimeInterval(hours * 3600)
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
        let julianDay = julianDay(for: date)
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
        
        let fajr = timeForAngle(angle: -calculationMethod.fajrAngle,
                                declination: solarDeclination,
                                latitude: latitude,
                                solarNoon: dhuhr,
                                isMorning: true)
        
        let maghrib = sunset
        
        let asrAngle = asrAltitudeAngle(declination: solarDeclination, latitude: latitude)
        let asr = timeForAngle(angle: asrAngle,
                               declination: solarDeclination,
                               latitude: latitude,
                               solarNoon: dhuhr,
                               isMorning: false)
        
        let isha: Double?
        if let minutes = calculationMethod.ishaMinutesAfterMaghrib, let maghrib = maghrib {
            isha = maghrib + Double(minutes) / 60.0
        } else {
            isha = timeForAngle(angle: -calculationMethod.ishaAngle,
                                declination: solarDeclination,
                                latitude: latitude,
                                solarNoon: dhuhr,
                                isMorning: false)
        }
        
        return RawTimes(
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha
        )
    }
    
    private func julianDay(for date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        
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
