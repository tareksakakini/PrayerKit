//
//  PrayerKitWidget.swift
//  PrayerKitWidget
//
//  Created by Tarek Sakakini on 11/24/25.
//

import WidgetKit
import SwiftUI

struct PrayerKitWidget: Widget {
    let kind: String = "PrayerKitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerKitTimelineProvider()) { entry in
            PrayerKitWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.13, blue: 0.26),
                            Color(red: 0.12, green: 0.22, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "prayertimes://"))
        }
        .configurationDisplayName("Prayer Kit")
        .description("View today's prayer times at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct PrayerKitWidgetEntryView: View {
    var entry: PrayerKitEntry
    
    private let gold = Color(red: 0.85, green: 0.75, blue: 0.55)
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()
    
    private static let periodFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }()
    
    var body: some View {
        Group {
            if let prayers = entry.prayers {
                VStack(spacing: 6) {
                    HStack {
                        Text(entry.hijriDate)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        if let nextPrayer = entry.nextPrayer {
                            HStack(spacing: 4) {
                                Text(nextPrayer.name.rawValue)
                                    .foregroundColor(gold)
                                Text("in")
                                    .foregroundColor(.white.opacity(0.7))
                                Text(nextPrayer.time, style: .timer)
                                    .monospacedDigit()
                                    .frame(width: 56, alignment: .trailing)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 12)
                    
                    HStack(spacing: 0) {
                        ForEach(prayers.prayers) { prayer in
                            let isNext = entry.nextPrayer?.name == prayer.name
                            
                            VStack(spacing: 3) {
                                Image(systemName: prayer.name.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(isNext ? gold : .white.opacity(0.5))
                                
                                Text(prayer.name.rawValue)
                                    .font(.system(size: 10, weight: isNext ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isNext ? .white : .white.opacity(0.6))
                                
                                Text(Self.timeFormatter.string(from: prayer.time))
                                    .font(.system(size: 13, weight: isNext ? .bold : .semibold, design: .rounded))
                                    .foregroundColor(isNext ? gold : .white)
                                
                                Text(Self.periodFormatter.string(from: prayer.time))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(isNext ? gold.opacity(0.8) : .white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isNext ? Color.white.opacity(0.1) : Color.clear)
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 28))
                        .foregroundColor(gold)
                    Text("Open app to set location")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    PrayerKitWidget()
} timeline: {
    PrayerKitEntry(
        date: Date(),
        prayers: nil,
        nextPrayer: nil,
        timeUntil: nil,
        cityName: "San Francisco",
        dateString: "Monday, November 24",
        hijriDate: "9 Ramadan 1447 AH"
    )
}
