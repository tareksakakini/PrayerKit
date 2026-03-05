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
            .accessoryRectangular
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
                    Text(display.title.prefix(3))
                        .font(.system(size: 10, weight: .bold))
                    Text(display.detail)
                        .font(.system(size: 9))
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

        default:
            Text("\(display.title) \(display.detail)")
        }
    }
}

