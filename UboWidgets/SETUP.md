# Ubo Widgets Setup

Follow these steps to add the widget extension to your Xcode project:

## 1. Add Widget Extension Target

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension**
3. Name it `UboWidgets`
4. Uncheck "Include Configuration App Intent" (we use static configuration)
5. Click **Finish**

## 2. Configure App Groups

Both the main app and widget need to share data via App Groups:

1. Select the main app target (`ubo-swift-app`)
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **App Groups**
4. Add group: `group.com.ubo.swift-app`

5. Select the widget target (`UboWidgetsExtension`)
6. Go to **Signing & Capabilities**
7. Click **+ Capability** and add **App Groups**
8. Add the same group: `group.com.ubo.swift-app`

## 3. Add Shared Files

Add these files to BOTH targets (main app and widget):

- `Shared/SharedSystemStats.swift`

To add to both targets:
1. Select the file in Xcode
2. Open the File Inspector (right panel)
3. Under "Target Membership", check both `ubo-swift-app` and `UboWidgetsExtension`

## 4. Replace Widget Files

Delete the auto-generated widget files and use our custom ones:

- Delete the auto-generated `UboWidgets.swift` and `UboWidgetsBundle.swift`
- Use the files in this folder:
  - `UboWidgetsBundle.swift`
  - `SystemStatusWidget.swift`

## 5. Build and Run

1. Build and run the main app on your device
2. Add the widget to your home screen:
   - Long press on home screen
   - Tap the **+** button
   - Search for "Ubo"
   - Choose your preferred widget size

## Widget Sizes

The widget supports multiple sizes:

- **Small**: Compact CPU, RAM, and temperature display
- **Medium**: Gauges with device info
- **Large**: Full dashboard with all stats
- **Lock Screen (Circular)**: CPU gauge
- **Lock Screen (Rectangular)**: CPU, RAM, and temp inline
- **Lock Screen (Inline)**: Text summary

## How It Works

1. The main app updates `SharedSystemStats` every 30 seconds via App Groups
2. The widget reads from this shared storage
3. Widget timeline refreshes every 5 minutes
4. Data older than 5 minutes shows as "stale" (red indicator)

## Troubleshooting

**Widget shows "Offline" or old data:**
- Make sure the main app is running and connected
- Check that App Groups are configured correctly on both targets
- Verify the group identifier matches: `group.com.ubo.swift-app`

**Widget doesn't appear in widget picker:**
- Clean build folder (Product > Clean Build Folder)
- Delete app from device and reinstall
- Restart the device
