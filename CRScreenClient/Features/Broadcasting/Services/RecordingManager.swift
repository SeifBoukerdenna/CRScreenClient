// CRScreenClient/Features/Broadcasting/Services/RecordingManager.swift

import Foundation
import AVFoundation
import UIKit
import SwiftUI

class RecordingManager {
    static let shared = RecordingManager()
    
    private let groupID = "group.com.elmelz.crcoach"
    private let kRecordingPathKey = "lastRecordingPath"
    
    private init() {}
    
    // Get the last recording created by the broadcast extension
    func getLastBroadcastRecording() -> URL? {
        guard let defaults = UserDefaults(suiteName: groupID),
              let recordingPath = defaults.string(forKey: kRecordingPathKey) else {
            Logger.error("No recording path found in UserDefaults", to: Logger.broadcast)
            return nil
        }
        
        let url = URL(fileURLWithPath: recordingPath)
        
        // Verify file exists
        if FileManager.default.fileExists(atPath: url.path) {
            Logger.info("Found recording at \(url.path)", to: Logger.broadcast)
            
            // Check file size
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? NSNumber {
                    let sizeInMB = Double(truncating: fileSize) / (1024 * 1024)
                    Logger.info("Recording file size: \(String(format: "%.2f", sizeInMB)) MB", to: Logger.broadcast)
                    
                    if fileSize.int64Value < 10000 {  // Less than 10KB
                        Logger.error("Recording file is too small, likely empty", to: Logger.broadcast)
                        return nil
                    }
                }
            } catch {
                Logger.error("Failed to get file attributes: \(error.localizedDescription)", to: Logger.broadcast)
            }
            
            // Verify it's a valid media file by checking asset properties
            let asset = AVAsset(url: url)
            
            // Log file details for debugging
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    
                    Logger.info("Recording details: Duration \(duration.seconds)s, Video tracks: \(tracks.count)", to: Logger.media)
                    
                    if duration.seconds > 0 && !tracks.isEmpty {
                        Logger.info("Recording is valid with proper duration and tracks", to: Logger.media)
                    } else {
                        Logger.error("Recording may be invalid: Duration \(duration.seconds)s, Video tracks: \(tracks.count)", to: Logger.media)
                    }
                } catch {
                    Logger.error("Error checking recording: \(error.localizedDescription)", to: Logger.media)
                }
            }
            
            return url
        } else {
            Logger.error("Recording file not found at \(url.path)", to: Logger.broadcast)
            return nil
        }
    }
    
    // Delete the recording file
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            Logger.info("Deleted recording at \(url.path)", to: Logger.broadcast)
            
            // Clear the recording path from UserDefaults
            UserDefaults(suiteName: groupID)?.removeObject(forKey: kRecordingPathKey)
        } catch {
            Logger.error("Failed to delete recording: \(error.localizedDescription)", to: Logger.broadcast)
        }
    }
    
    // Simulate sending the recording to a server
    func sendRecordingToServer(at url: URL, completion: @escaping (Bool) -> Void) {
        // In a real implementation, this would upload the file to a server
        // For now, we'll just simulate the process with a delay
        
        Logger.info("Preparing to send recording at \(url.path)", to: Logger.broadcast)
        
        // Check file size for debugging
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                let sizeInMB = Double(truncating: fileSize) / (1024 * 1024)
                Logger.info("Recording file size: \(String(format: "%.2f", sizeInMB)) MB", to: Logger.broadcast)
            }
        } catch {
            Logger.error("Failed to get file size: \(error.localizedDescription)", to: Logger.broadcast)
        }
        
        // Simulate upload process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Logger.info("Recording would be sent to server", to: Logger.broadcast)
            completion(true)
            
            // Clear the recording path from UserDefaults after successful upload
            UserDefaults(suiteName: self.groupID)?.removeObject(forKey: self.kRecordingPathKey)
        }
    }
}
