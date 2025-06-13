# CRScreenClient

**Real-time iOS Screen Broadcasting Client for Clash Royale Coaching**

CRScreenClient is a SwiftUI-based iOS application that enables real-time screen sharing and broadcasting for Clash Royale gameplay analysis. It connects to the [CRCoach](https://github.com/yourusername/CRCoach) server ecosystem to provide seamless coaching experiences.

## 🎯 Overview

CRScreenClient transforms your iOS device into a powerful broadcasting tool for Clash Royale coaching sessions. Players can broadcast their gameplay in real-time while coaches connect via the web interface to provide live feedback and analysis.

### Key Features

- **🔴 Real-time Screen Broadcasting** - Stream your Clash Royale gameplay with minimal latency
- **📱 ReplayKit Integration** - Native iOS screen recording with broadcast extensions
- **🌐 WebRTC Streaming** - Low-latency peer-to-peer video streaming
- **🎮 4-Digit Session Codes** - Simple connection system for coach-player sessions
- **⚙️ Quality Controls** - Adjustable streaming quality (Low/Medium/High)
- **📊 Performance Monitoring** - Real-time stats and connection diagnostics
- **💾 Local Recording** - Automatic session recording with playback
- **🔧 Debug Tools** - Comprehensive debugging and server configuration options

## 🏗️ Architecture

### Core Components

```
CRScreenClient/
├── App/                          # App entry point
│   └── CRScreenClientApp.swift   # Main app configuration
├── Core/                         # Core functionality
│   ├── Constants/                # App constants and configuration
│   ├── Extensions/               # Swift extensions (Color, etc.)
│   ├── Debug/                    # Debug settings and tools
│   └── WebRTC/                   # WebRTC client implementation
├── Features/                     # Feature modules
│   ├── Broadcasting/             # Broadcasting logic
│   │   └── Models/               # BroadcastManager, StorageManager
│   └── UI/                       # User interface
│       ├── Components/           # Reusable UI components
│       └── Screens/              # Main app screens
└── CRScreenClientBroadcast/      # Broadcast extension
    └── SampleHandler.swift       # ReplayKit broadcast handler
```

### Connection Flow

1. **Session Creation**: App generates a 4-digit session code
2. **Broadcast Start**: User initiates ReplayKit broadcast
3. **WebRTC Setup**: Extension establishes WebRTC connection to server
4. **Coach Connection**: Coach connects via web interface using session code
5. **Real-time Streaming**: Video frames stream with low latency
6. **Local Recording**: Sessions automatically recorded for later review

## 🔧 Technical Stack

### iOS App (SwiftUI)
- **Framework**: SwiftUI + Combine
- **Broadcasting**: ReplayKit + Broadcast Extension
- **Video Streaming**: WebRTC (iOS)
- **Storage**: UserDefaults + File System
- **Networking**: URLSession WebSocket

### Dependencies
- **WebRTC**: Real-time video streaming
- **ReplayKit**: iOS screen recording
- **AVFoundation**: Video processing
- **Combine**: Reactive programming

### Server Integration
- **WebRTC Signaling**: WebSocket connection to CRCoach server
- **Session Management**: 4-digit code system
- **Quality Adaptation**: Dynamic bitrate and resolution adjustment

## 🚀 Getting Started

### Prerequisites

- iOS 14.0+
- Xcode 13.0+
- Active Apple Developer Account (for ReplayKit)
- CRCoach server running (see [CRCoach Repository](../server/))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/CRScreenClient.git
   cd CRScreenClient
   ```

2. **Open in Xcode**
   ```bash
   open CRScreenClient.xcodeproj
   ```

3. **Configure Bundle IDs**
   - Update bundle identifiers in project settings
   - Ensure broadcast extension ID matches: `com.elmelz.CRScreenClient.Broadcast`

4. **Set App Group**
   - Configure App Group: `group.com.elmelz.crcoach`
   - Enable App Groups capability for both app and extension

5. **Build and Run**
   - Select your device
   - Build and install both app and broadcast extension

### Server Configuration

The app connects to CRCoach server for WebRTC signaling:

```swift
// Default server configuration
static let webRTCSignalingServer = "ws://35.208.133.112:8080/ws"
static let defaultBroadcastServer = "http://35.208.133.112:8080/"
```

#### Custom Server Setup
Access debug menu (triple-tap) to configure custom server:
- **Custom URL**: Set your server endpoint
- **Secure Connection**: Enable HTTPS/WSS
- **Custom Port**: Override default port

## 📱 Usage

### Starting a Broadcast Session

1. **Launch App**: Open CRScreenClient
2. **Session Code**: Note the 4-digit code displayed
3. **Start Broadcast**: Tap broadcast button
4. **Select Extension**: Choose "CRScreenClient Broadcast"
5. **Begin Streaming**: Tap "Start Broadcast"

### Quality Settings

Adjust streaming quality based on connection:

- **🔵 Low Quality**
  - Bitrate: 400 kbps
  - Resolution: 40% scale
  - Framerate: 12 fps
  - Best for: Slow connections

- **🟡 Medium Quality** (Default)
  - Bitrate: 800 kbps
  - Resolution: 70% scale  
  - Framerate: 20 fps
  - Best for: Balanced performance

- **🟣 High Quality**
  - Bitrate: 1200 kbps
  - Resolution: 85% scale
  - Framerate: 24 fps
  - Best for: Fast connections

### Session Management

- **Recent Broadcasts**: View and replay past sessions
- **Local Recordings**: Access recorded gameplay
- **Connection Stats**: Monitor streaming performance
- **Debug Info**: Detailed technical diagnostics

## 🔧 Configuration

### Constants.swift

Key configuration options:

```swift
enum URLs {
    static let webRTCSignalingServer = "ws://your-server:8080/ws"
    static let defaultBroadcastServer = "http://your-server:8080/"
    static let webApp = "royaltrainer.com"
}

enum Broadcast {
    static let extensionID = "com.yourteam.CRScreenClient.Broadcast"
    static let groupID = "group.com.yourteam.crcoach"
}

enum WebRTC {
    static let maxReconnectAttempts = 3
    static let connectionTimeout: TimeInterval = 8.0
}
```

### Feature Flags

```swift
enum FeatureFlags {
    static let enableDebugLogging = true
    static let enablePerformanceMonitoring = true
    static let enableLocalRecording = true
}
```

## 🐛 Debug Features

### Debug Menu Access
Triple-tap anywhere on the main screen to access debug tools:

- **Server Configuration**: Custom server settings
- **Connection Diagnostics**: WebRTC connection details
- **Performance Metrics**: CPU, memory, and network stats
- **Watermark Controls**: Anti-piracy watermark management
- **Quality Override**: Manual quality parameter adjustment

### Logging

Enable detailed logging:
```swift
Constants.FeatureFlags.enableDebugLogging = true
```

View logs in Xcode console or device logs.

## 🔗 Integration with CRCoach

### Server Communication

1. **Session Registration**: App registers 4-digit codes with server
2. **WebRTC Signaling**: Establishes peer connections via server
3. **Status Updates**: Real-time broadcast state synchronization
4. **Recording Upload**: Optional server-side session storage

### Web Client Integration

CRScreenClient works seamlessly with the web-based coaching interface:

- **Coach Dashboard**: Real-time session monitoring
- **Multi-viewer Support**: Multiple coaches per session
- **Inference Integration**: AI-powered gameplay analysis
- **Session Recording**: Server-side session archival

### API Endpoints

- `GET /health` - Server health check
- `WS /ws/{session_code}` - WebRTC signaling
- `POST /upload/` - Recording upload
- `GET /session/{code}/status` - Session status

## 📊 Performance Optimization

### Adaptive Quality

The app automatically adjusts streaming parameters based on:
- **Device Performance**: CPU and memory usage
- **Network Conditions**: Bandwidth and latency
- **Frame Processing**: Real-time frame analysis

### Optimization Features

- **Dynamic Frame Skipping**: Maintains smooth performance
- **Adaptive Bitrate**: Adjusts to network conditions  
- **Smart Compression**: Optimized video encoding
- **Background Processing**: Efficient resource management

## 🛠️ Development

### Building from Source

1. **Prerequisites**
   ```bash
   # Xcode 13.0+
   # iOS 14.0+ deployment target
   # Apple Developer Account
   ```

2. **Configuration**
   ```bash
   # Update bundle IDs in project settings
   # Configure App Groups capability
   # Set broadcast extension bundle ID
   ```

3. **Dependencies**
   - No external package managers required
   - All dependencies included in project

### Project Structure

```
├── CRScreenClient.xcodeproj          # Xcode project
├── CRScreenClient/                   # Main app target
├── CRScreenClientBroadcast/          # Broadcast extension
├── CRShared.swift                    # Shared code
└── README.md                         # This file
```

### Key Files

- **`CRScreenClientApp.swift`**: App entry point and configuration
- **`MainScreen.swift`**: Primary user interface
- **`BroadcastManager.swift`**: Session and broadcasting logic
- **`WebRTCManager.swift`**: WebRTC client implementation
- **`SampleHandler.swift`**: ReplayKit broadcast extension
- **`Constants.swift`**: App configuration and endpoints

## 📱 System Requirements

### iOS App
- **iOS Version**: 14.0 or later
- **Device**: iPhone or iPad
- **Storage**: 50MB minimum
- **Network**: Wi-Fi or cellular data

### Server Requirements
- **CRCoach Server**: Running WebRTC signaling service
- **Port Access**: 8080 (default) or custom configured
- **Protocol**: WebSocket (WS/WSS) support

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open Pull Request**

### Development Guidelines

- Follow Swift style guidelines
- Add appropriate logging for debugging
- Test on multiple iOS versions
- Ensure ReplayKit extension compatibility
- Maintain WebRTC connection stability

## 📄 License

This project is part of the CRCoach ecosystem. See the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Common Issues

**Broadcast Not Starting**
- Check App Groups configuration
- Verify bundle IDs match
- Ensure ReplayKit permissions

**Connection Failed**
- Verify server is running
- Check network connectivity
- Review WebRTC signaling logs

**Poor Video Quality**
- Adjust quality settings
- Check network bandwidth
- Monitor device performance

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/yourusername/CRScreenClient/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/CRScreenClient/discussions)
- **Server Issues**: [CRCoach Repository](https://github.com/yourusername/CRCoach)

## 🔄 Changelog

### v1.0.0
- Initial release
- ReplayKit broadcasting
- WebRTC streaming
- 4-digit session codes
- Quality controls
- Local recording
- Debug tools

---

**CRScreenClient** - Empowering Clash Royale coaching through real-time screen sharing 🏆
