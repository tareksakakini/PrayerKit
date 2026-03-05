# Debugging Widget Issues

## Current Issue: Widget shows "Open app to set location"

This means the widget is working, but it's not receiving data from the main app. Here's how to fix it:

## Step 1: Verify App Groups Configuration

1. **In Xcode, select your PrayerTimes app target**
   - Go to **Signing & Capabilities** tab
   - Check if **App Groups** capability is present
   - Verify it contains: `group.tektechinc.PrayerTimes.shared`
   - If not, click **+ Capability** → **App Groups** → Add the group

2. **Select PrayerTimesWidget target**
   - Go to **Signing & Capabilities** tab
   - Check if **App Groups** capability is present
   - Verify it contains the **SAME** group: `group.tektechinc.PrayerTimes.shared`
   - Both targets MUST have the exact same App Group identifier

## Step 2: Run the Main App First

1. **Build and run the PrayerTimes app** (not the widget)
2. **Allow location permission** when prompted
3. **Wait for prayer times to load** in the app
4. Check the Xcode console for these messages:
   - `✅ SharedDataManager: Saved location: ...`
   - `✅ SharedDataManager: Saved prayer times successfully`

If you don't see these messages, App Groups might not be configured correctly.

## Step 3: Check Console Logs

After running the app, check the Xcode console for:
- `⚠️ SharedDataManager: Failed to create UserDefaults...` - This means App Groups aren't configured
- `✅ SharedDataManager: Saved location...` - This means data is being saved

## Step 4: Test the Widget

1. After the app has run and saved data:
2. Go to home screen
3. Long press → Add widget → Prayer Times
4. The widget should now show prayer times

If it still shows "Open app to set location":
- Remove the widget
- Re-run the main app
- Re-add the widget

## Step 5: Verify Data is Saved

You can add this temporary code to check if data is being saved:

```swift
// In your app, after location is set:
let shared = SharedDataManager.shared
print("App Group available: \(shared.isAppGroupAvailable())")
print("Location saved: \(shared.loadLocation() != nil)")
print("Prayer times saved: \(shared.loadPrayerTimes() != nil)")
```

## Common Issues

### Issue: "App Group not available" in console
**Solution**: App Groups capability is not configured correctly. Make sure:
- Both targets have the capability
- The identifier matches exactly: `group.tektechinc.PrayerTimes.shared`
- You're signed in with your Apple Developer account

### Issue: Location is saved but widget doesn't show it
**Solution**: 
- Make sure both app and widget are using the same App Group identifier
- Try removing and re-adding the widget
- Restart the device/simulator

### Issue: Widget shows data but it's outdated
**Solution**: The widget updates automatically, but you can force refresh by:
- Removing and re-adding the widget
- Or wait for the next prayer time (widget updates automatically)

