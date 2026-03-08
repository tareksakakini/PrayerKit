import WidgetKit
import SwiftUI

struct NextPrayerComplication: Widget {
    let kind: String = "NextPrayerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: PrayerKitTimelineProvider()) { entry in
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
    let entry: PrayerKitEntry

    private var fallbackDisplay: (title: String, detail: String) {
        ("No upcoming", "Open app")
    }

    private var cornerTitle: String {
        guard let next = entry.nextPrayer else { return fallbackDisplay.title }
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
            if let next = entry.nextPrayer {
                HStack(spacing: 4) {
                    Text(next.name.rawValue)
                    Text(next.time, style: .timer)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .widgetLabel("\(next.name.rawValue)")
            } else {
                HStack(spacing: 4) {
                    Text(fallbackDisplay.title)
                    Text(fallbackDisplay.detail)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .widgetLabel("\(fallbackDisplay.title) \(fallbackDisplay.detail)")
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    if let next = entry.nextPrayer {
                        Text(next.name.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                        Text(next.time, style: .timer)
                            .font(.system(size: 7, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                    } else {
                        Text(fallbackDisplay.title)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                        Text(fallbackDisplay.detail)
                            .font(.system(size: 7, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .widgetLabel {
                if let next = entry.nextPrayer {
                    Text(next.time, style: .timer)
                } else {
                    Text("\(fallbackDisplay.title) \(fallbackDisplay.detail)")
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                if let next = entry.nextPrayer {
                    Text(next.name.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    Text(next.time, style: .timer)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                } else {
                    Text(fallbackDisplay.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(fallbackDisplay.detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .widgetLabel {
                if let next = entry.nextPrayer {
                    Text(next.time, style: .timer)
                } else {
                    Text("\(fallbackDisplay.title) \(fallbackDisplay.detail)")
                }
            }

        case .accessoryCorner:
            if let next = entry.nextPrayer {
                Text(cornerTitle)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(prayerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .widgetCurvesContent()
                .widgetLabel {
                    Text(next.time, style: .timer)
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
            if let next = entry.nextPrayer {
                HStack(spacing: 4) {
                    Text(next.name.rawValue)
                    Text(next.time, style: .timer)
                }
            } else {
                Text("\(fallbackDisplay.title) \(fallbackDisplay.detail)")
            }
        }
    }
}
