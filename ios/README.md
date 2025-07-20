# ClipboardSync iOS App

A SwiftUI app that provides identical functionality to the Windows ClipboardSync application.

## Features

- **Bidirectional clipboard sync** between iOS and other devices
- **Real-time monitoring** of clipboard changes  
- **File transfer support** with base64 encoding (up to 50MB)
- **Interactive notifications** with content preview and copy/cancel buttons
- **Identical UI** to the Windows version
- **Background polling** every 2 seconds

## Setup Instructions

1. **Open in Xcode**: Open `ClipboardSync.xcodeproj` on your macbook
2. **Configure server URL**: Edit `Config.swift` and update `serverUrl` to your server's IP address
3. **Set your team**: In Xcode project settings, set your Apple Developer account for code signing
4. **Build & Run**: Connect your iPad and build to device
5. **Grant permissions**: Allow notifications when prompted

## Architecture

- **ClipboardManager**: Monitors local clipboard changes and handles send/receive
- **ServerManager**: Manages HTTP communication with the Node.js server
- **NotificationManager**: Shows interactive alerts for received content
- **ContentView**: Main UI matching the Windows app design

## iOS-Specific Adaptations

### Clipboard Access
- iOS doesn't allow background clipboard monitoring, so we poll every 500ms when app is active
- Received content shows as interactive alert (not system notification) for better UX

### File Handling
- Files are saved to app's Documents directory under `ClipboardSync/` folder
- Uses `UIPasteboard.urls` for file clipboard integration
- Supports the same file types and size limits as Windows version

### Background Operation
- Uses `BGTaskScheduler` for background refresh (when app is backgrounded)
- Polls server every 2 seconds when in foreground
- Shows badge count for pending clipboard items

## Usage

1. **Outgoing**: Copy anything → automatically sends to server → shows "✓ Clipboard sent successfully"
2. **Incoming**: Server has new content → shows interactive alert with preview → tap "Copy" → content is now in your clipboard

The app provides the exact same experience as the Windows version, adapted for iOS conventions.