import Foundation
import SwiftUI

enum Constants {
    enum URLs {
        static let demoVideo = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        static let broadcastServer = "http://192.168.2.150:8080/upload/"
        static let webApp = "royaltrainer.com"
    }
    
    enum AppGroup {
        static let identifier = "group.com.elmelz.crcoach"
    }
    
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonBorderWidth: CGFloat = 3
        static let animationDuration: Double = 0.3
        static let defaultPadding: CGFloat = 16
    }
    
    enum Broadcast {
        static let extensionID = "com.elmelz.CRScreenClient.Broadcast"
    }
    
    enum FeatureFlags {
            static let enablePictureInPicture = true
            static let enableDebugLogging = true
            static let useLocalVideoOnly = false
        }
}
