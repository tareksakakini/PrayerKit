import WidgetKit
import SwiftUI

struct NextPrayerComplication: Widget {
    let kind: String = "NextPrayerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: PrayerTimesTimelineProvider()) { entry in
            NextPrayerComplicationView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("Shows the next prayer and time remaining.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner
        ])
    }
}

struct NextPrayerComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerTimesEntry

    private var display: (title: String, detail: String) {
        guard let next = entry.nextPrayer,
              let timeUntil = entry.timeUntil else {
            return ("No upcoming", "Open app")
        }
        return (next.name.rawValue, "in \(timeUntil)")
    }
    
    /// Progress (0–1) from previous prayer to next prayer for corner gauge (uses entry date for seamless updates)
    private func cornerGaugeProgress(prayers: DailyPrayers, nextPrayer: Prayer, asOf date: Date) -> Double {
        guard let nextIndex = prayers.prayers.firstIndex(where: { $0.name == nextPrayer.name }),
              nextIndex > 0 else {
            return 0.5 // First prayer of day: show halfway
        }
        let prev = prayers.prayers[nextIndex - 1]
        let total = nextPrayer.time.timeIntervalSince(prev.time)
        let elapsed = date.timeIntervalSince(prev.time)
        guard total > 0 else { return 1 }
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            HStack(spacing: 4) {
                Text(display.title)
                Text(display.detail)
                    .foregroundColor(.secondary)
            }

        case .accessoryCircular:
            ZStack {
                Circle().strokeBorder(.secondary, lineWidth: 2)
                VStack(spacing: 2) {
                    Text(display.title)
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(display.detail)
                        .font(.system(size: 8))
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(display.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(entry.hijriDate)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

        case .accessoryCorner:
            if let next = entry.nextPrayer, entry.timeUntil != nil, let prayers = entry.prayers {
                let progress = cornerGaugeProgress(prayers: prayers, nextPrayer: next, asOf: entry.date)
                Gauge(value: progress, in: 0...1) {
                    Image(systemName: next.name.icon)
                } currentValueLabel: {
                    EmptyView()
                } minimumValueLabel: {
                    EmptyView()
                } maximumValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetLabel {
                    Text("\(display.title) \(display.detail)")
                }
            } else {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 24, weight: .medium))
                    .widgetLabel {
                        Text("Open app")
                    }
            }

        default:
            Text("\(display.title) \(display.detail)")
        }
    }
}

