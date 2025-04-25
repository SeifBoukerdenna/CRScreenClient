import Foundation
import OSLog

/// Centralized logging service
enum Logger {
    static let broadcast = OSLog(subsystem: "com.elmelz.CRScreenClient", category: "Broadcast")
    static let pip = OSLog(subsystem: "com.elmelz.CRScreenClient", category: "PictureInPicture")
    static let media = OSLog(subsystem: "com.elmelz.CRScreenClient", category: "Media")
    static let app = OSLog(subsystem: "com.elmelz.CRScreenClient", category: "App")
    
    static func log(_ message: String, to logger: OSLog = app, type: OSLogType = .default) {
        os_log("%{public}@", log: logger, type: type, message)
    }
    
    static func error(_ message: String, to logger: OSLog = app) {
        log(message, to: logger, type: .error)
    }
    
    static func info(_ message: String, to logger: OSLog = app) {
        log(message, to: logger, type: .info)
    }
    
    static func debug(_ message: String, to logger: OSLog = app) {
        #if DEBUG
        log(message, to: logger, type: .debug)
        #endif
    }
}
