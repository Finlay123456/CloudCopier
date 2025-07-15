# CloudCopier iOS App

A Swift iOS application that receives clipboard updates from your CloudCopier server and provides interactive notifications with copy/ignore options.

## Features

- **Real-time sync**: Connects to CloudCopier server via WebSocket
- **Interactive notifications**: Shows content preview with Copy/Ignore actions
- **Multiple formats**: Supports text, HTML, RTF, images, and files
- **Smart previews**: Displays appropriate previews for different content types
- **Background operation**: Continues working when app is in background

## Setup

1. Open `CloudCopier.xcodeproj` in Xcode
2. Update the bundle identifier in project settings
3. Build and run on iPad/iPhone (iOS 15.0+)

## Usage

1. Launch the app
2. Enter your CloudCopier server URL (e.g., `ws://192.168.1.100:3000`)
3. Toggle "Enable Clipboard Sync" to ON
4. Minimize the app - it will run in background
5. When clipboard data is received, you'll get a notification with:
   - Preview of the content
   - "Copy" button to add to iPad clipboard
   - "Ignore" button to dismiss

## Configuration

- **Server URL**: WebSocket URL of your CloudCopier server
- **Notifications**: App will request notification permissions on first launch
- **Background**: App supports background processing for real-time updates

## Requirements

- iOS 15.0 or later
- iPhone/iPad
- Network access to CloudCopier server
- Notification permissions for interactive alerts

## File Structure

- `CloudCopierApp.swift` - Main app entry point
- `ContentView.swift` - Main UI with connection toggle
- `ClipboardManager.swift` - WebSocket handling and notifications
- `ClipboardItem.swift` - Data model for clipboard items
- `Info.plist` - App configuration and permissions