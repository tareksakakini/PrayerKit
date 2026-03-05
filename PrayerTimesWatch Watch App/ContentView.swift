//
//  ContentView.swift
//  PrayerTimesWatch Watch App
//
//  Created by Tarek Sakakini on 3/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var prayers: DailyPrayers?
    @State private var cityName: String = ""
    @State private var hijriDate: String = ""
    
    var body: some View {
        Group {
            if let prayers = prayers {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let next = prayers.nextPrayer {
                            HStack {
                                Image(systemName: next.name.icon)
                                    .font(.caption)
                                Text(next.name.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text(next.formattedTime)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider()
                        
                        ForEach(prayers.prayers) { prayer in
                            HStack {
                                Image(systemName: prayer.name.icon)
                                    .font(.caption2)
                                    .frame(width: 20, alignment: .leading)
                                Text(prayer.name.rawValue)
                                    .font(.caption)
                                Spacer()
                                Text(prayer.formattedTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !hijriDate.isEmpty {
                            Text(hijriDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                    Text("Open iPhone app")
                        .font(.caption)
                    Text("to set location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(cityName.isEmpty ? "Prayer Times" : cityName)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        let shared = SharedDataManager.shared
        prayers = shared.loadPrayerTimes()
        cityName = shared.loadCityName()
        
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamic
        formatter.dateFormat = "d MMMM yyyy"
        hijriDate = formatter.string(from: Date()) + " AH"
    }
}

#Preview {
    ContentView()
}
