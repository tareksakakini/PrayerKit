# Debugging Widget Issues

## Current Issue: Widget shows "Open app to set location"

This means the widget is working, but it's not receiving data from the main app. Here's how to fix it:

## Step 1: Verify App Groups Configuration

1. **In Xcode, select your Prayer Kit app target**
   - Go to **Signing & Capabilities** tab
   - Check if **App Groups** capability is present
   - Verify it contains: `group.tektechinc.PrayerKit.shared`
   - If not, click **+ Capability** → **App Groups** → Add the group

2. **Select PrayerKitWidget target**
   - Go to **Signing & Capabilities** tab
   - Check if **App Groups** capability is present
   - Verify it contains the **SAME** group: `group.tektechinc.PrayerKit.shared`
   - Both targets MUST have the exact same App Group identifier

## Step 2: Run the Main App First

1. **Build and run the Prayer Kit app** (not the widget)
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
3. Long press → Add widget → Prayer Kit
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
- The identifier matches exactly: `group.tektechinc.PrayerKit.shared`
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

---

## Watch App & Complication

**Important**: The Watch runs on a separate device. It cannot access the iPhone's App Group. Data syncs via **WatchConnectivity** when both devices are paired.

### Testing Order (Must Run on Physical Devices)

1. **Run the main Prayer Kit app on your iPhone**
   - Allow location permission
   - Wait for prayer times to load (you should see Fajr, Dhuhr, etc.)
   - This sends data to the Watch via WatchConnectivity

2. **Open the Prayer Kit Watch app on your Apple Watch**
   - This activates the WatchConnectivity session
   - Data should sync from the iPhone
   - You should see prayer times instead of "Open iPhone app"

3. **Add the complication to your watch face**
   - Long press on watch face → Edit → Add complication
   - Choose "Next Prayer" under Prayer Kit
   - It should show "Fajr in Xh Xm" (or the next prayer)

### Simulator vs Physical Device

- **WatchConnectivity does NOT work in the simulator** – iPhone and Watch simulators cannot communicate
- You must use a **paired physical iPhone + Apple Watch** for testing
- The Watch app and complication will show "Open app" / "No upcoming" in the simulator

### If Watch still shows "Open app" or "Hello World"

1. Ensure iPhone and Watch are paired and unlocked
2. Run the main app on iPhone first, wait for it to load
3. Open the Watch app once – this triggers the sync
4. Force close and reopen the Watch app
5. Rebuild and reinstall the Watch app from Xcode

### Two Different Things

- **Watch App** = The app you tap to open on the Watch (shows full prayer list)
- **Watch Complication** = The small widget on the watch face (shows next prayer only)

