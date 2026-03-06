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

    private var oneLineStatus: String {
        "\(display.title) \(display.detail)"
    }

    private var cornerTitle: String {
        guard let next = entry.nextPrayer else { return display.title }
        switch next.name {
        case .fajr:
            return "Fjr"
        case .sunrise:
            return "Sun"
        case .dhuhr:
            return "Dhr"
        case .asr:
            return "Asr"
        case .maghrib:
            return "Mgrb"
        case .isha:
            return "Isha"
        }
    }

    private var prayerColor: Color {
        guard let next = entry.nextPrayer else { return .secondary }
        switch next.name {
        case .fajr:
            return .cyan
        case .sunrise:
            return .orange
        case .dhuhr:
            return .yellow
        case .asr:
            return .mint
        case .maghrib:
            return .pink
        case .isha:
            return .indigo
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            HStack(spacing: 4) {
                Text(display.title)
                Text(display.detail)
                    .foregroundColor(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .widgetLabel("\(display.title) \(display.detail)")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(display.title)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                    Text(display.detail)
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                .multilineTextAlignment(.center)
            }
            .widgetLabel {
                Text("\(display.title) \(display.detail)")
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(display.detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .widgetLabel("\(display.title) \(display.detail)")

        case .accessoryCorner:
            if entry.nextPrayer != nil, entry.timeUntil != nil {
                Text(cornerTitle)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(prayerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .widgetCurvesContent()
                .widgetLabel {
                    Text(display.detail)
                }
            } else {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .widgetLabel {
                        Text("Open app")
                    }
            }

        default:
            Text("\(display.title) \(display.detail)")
        }
    }
}
