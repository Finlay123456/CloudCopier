# CloudCopier

Cross-device clipboard sync between Windows and iOS. Copy on one device, paste on another.

## How it works

Three components:
- **Windows app** (C# WinForms) - monitors clipboard changes, syncs with server
- **Node.js server** - stores clipboard data, handles API requests  
- **iOS app** (Swift/SwiftUI) - monitors clipboard changes, syncs with server

Both apps detect local clipboard changes and upload to server. Both apps poll server and update local clipboard when remote changes are detected.

## Features

- Syncs text and images
- API key authentication
- Works offline (queues changes)
- Native apps, no web wrappers
- Self-hostable

## Setup

### Server

```bash
cd server
npm install
npm start
# or with Docker
docker build -t cloudcopier .
docker run -p 3000:3000 -e API_KEY=your-secret-key cloudcopier
```

### Windows Client

```bash
cd windows
dotnet build
dotnet run
```

Configure server URL in `config.json`.

### iOS App

Open `ios/ClipboardSync.xcodeproj` in Xcode. Update server URL in `Config.swift`, then build and run on device.

## API

### Authentication
Include `X-API-Key` header in all requests.

### POST /clipboard
```json
{
  "formats": {
    "text": "content here",
    "image": "base64-data"
  },
  "source": "windows"
}
```

### GET /clipboard
Returns latest clipboard data with timestamp and format info.

### GET /health
Server health check.

## Configuration

### Server Environment Variables
- `PORT` - Server port (default: 3000)
- `API_KEY` - Authentication key (required)

### Client Configuration

**iOS** (`ios/ClipboardSync/Config.swift`):
```swift
struct AppConfig {
    static let serverUrl = "https://your-server.com"
    static let apiKey = "your-api-key"
    static let pollingInterval: TimeInterval = 2.0
}
```

**Windows** (`windows/config.json`):
```json
{
  "serverUrl": "https://your-server.com",
  "apiKey": "your-api-key",
  "pollingInterval": 2000
}
```

## Deployment

Works on Railway, Heroku, AWS, or anywhere that runs Node.js. The included Dockerfile makes container deployment straightforward.

## TODO

- WebSocket support for real-time sync
- File/image support improvements  
- Android client
- Clipboard history
- End-to-end encryption

## License

MIT
