# Widget Extension Setup Guide

This guide will help you add the Widget Extension to your Xcode project.

## Step 1: Add Widget Extension Target in Xcode

1. Open your project in Xcode
2. Go to **File** → **New** → **Target**
3. Select **Widget Extension** under iOS
4. Click **Next**
5. Configure:
   - **Product Name**: `PrayerTimesWidget`
   - **Organization Identifier**: (same as your main app)
   - **Language**: Swift
   - **Include Configuration Intent**: No (uncheck this)
6. Click **Finish**
7. When prompted, click **Activate** to activate the scheme

## Step 2: Configure App Groups

Both the main app and widget extension need to share data using App Groups.

1. Select your **PrayerTimes** app target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.tektechinc.PrayerTimes.shared`
6. Repeat for the **PrayerTimesWidget** target:
   - Select **PrayerTimesWidget** target
   - Go to **Signing & Capabilities** tab
   - Add **App Groups** capability
   - Add the same group: `group.tektechinc.PrayerTimes.shared`

**Important**: The App Group identifier must match your bundle identifier format. For this project, it's `group.tektechinc.PrayerTimes.shared`. If you see errors about the App Group not being available:
- Make sure you're signed in with your Apple Developer account in Xcode
- The App Group will be automatically created when you add it in Xcode (for development)
- For production, you may need to register it in the Apple Developer Portal

## Step 3: Add Shared Files to Widget Extension Target

The widget extension needs access to your models and services. You need to add these files to the widget extension target:

1. In Xcode, select the following files in the Project Navigator:
   - `PrayerTimes/Models/Prayer.swift`
   - `PrayerTimes/Services/PrayerTimeCalculator.swift`
   - `PrayerTimes/Services/SharedDataManager.swift`

2. For each file:
   - Open the **File Inspector** (right panel)
   - Under **Target Membership**, check **PrayerTimesWidget**

Alternatively, you can:
- Select the files
- Right-click → **Show File Inspector**
- Under **Target Membership**, check both **PrayerTimes** and **PrayerTimesWidget**

## Step 4: Replace Default Widget Files

The widget extension target will create default files. Replace them with the files in the `PrayerTimesWidget` folder:

1. Delete the default widget files created by Xcode (if any)
2. The following files should already be in place:
   - `PrayerTimesWidget/PrayerTimesWidget.swift`
   - `PrayerTimesWidget/PrayerTimesWidgetTimelineProvider.swift`
   - `PrayerTimesWidget/PrayerTimesWidgetBundle.swift`
   - `PrayerTimesWidget/Info.plist`

## Step 5: Update Bundle Identifier

Make sure the widget extension has a proper bundle identifier:
- It should be: `com.yourcompany.PrayerTimes.PrayerTimesWidget` (or similar)
- Check in **Build Settings** → **Product Bundle Identifier**

## Step 6: Build and Run

1. Select the **PrayerTimesWidget** scheme
2. Build the project (⌘B)
3. If there are any import errors, make sure the shared files are added to the widget target (Step 3)

## Step 7: Test the Widget

1. Run the main app first to generate prayer times data
2. Go to the home screen
3. Long press on an empty area
4. Tap the **+** button in the top-left
5. Search for "Prayer Times"
6. Add the widget to your home screen

## Troubleshooting

### Widget shows "No data" or empty
- Make sure you've run the main app at least once to generate prayer times
- Check that App Groups are configured correctly for both targets
- Verify the App Group identifier matches in `SharedDataManager.swift`

### Build errors about missing types
- Ensure all model and service files are added to the widget extension target (Step 3)
- Check that imports are correct

### Widget doesn't update
- Widgets update on a schedule managed by iOS
- The timeline provider is configured to update at prayer times
- You can force a refresh by removing and re-adding the widget

## Widget Sizes

The widget supports three sizes:
- **Small**: Shows next prayer with icon and time
- **Medium**: Shows next prayer on left, list of prayers on right
- **Large**: Shows full prayer times list with next prayer highlighted

