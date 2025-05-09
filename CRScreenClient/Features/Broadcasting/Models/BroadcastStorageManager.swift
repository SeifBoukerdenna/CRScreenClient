import Foundation
import AVFoundation

class BroadcastStorageManager: ObservableObject {
    @Published private(set) var broadcasts: [BroadcastRecord] = []
    
    private let maxBroadcasts = 10
    private let storageKey = "recentBroadcasts"
    private let groupID = "group.com.elmelz.crcoach"
    
    init() {
        loadBroadcasts()
        scanForMissingRecordings()
    }
    
    private func loadBroadcasts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            let decodedBroadcasts = try JSONDecoder().decode([BroadcastRecord].self, from: data)
            
            // Filter out broadcasts whose files don't exist anymore
            broadcasts = decodedBroadcasts.filter { record in
                FileManager.default.fileExists(atPath: record.fileURL.path)
            }
            
            // Update file sizes
            broadcasts = broadcasts.map { record in
                var updatedRecord = record
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: record.fileURL.path)
                    updatedRecord.fileSize = attributes[.size] as? Int64 ?? 0
                } catch {
                    Logger.error("Failed to get file size for \(record.fileURL.path): \(error)", to: Logger.app)
                }
                return updatedRecord
            }
            
            // Sort by date, newest first
            broadcasts.sort { $0.date > $1.date }
            
        } catch {
            Logger.error("Failed to load broadcasts: \(error)", to: Logger.app)
        }
    }
    
    private func saveBroadcasts() {
        do {
            let data = try JSONEncoder().encode(broadcasts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.error("Failed to save broadcasts: \(error)", to: Logger.app)
        }
    }
    
    // Public method to refresh broadcasts list
    func refreshBroadcasts() {
        loadBroadcasts()
        scanForMissingRecordings()
    }
    
    // Scan for recordings that aren't in our list
    private func scanForMissingRecordings() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return
        }
        
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Get all MP4 files in the recordings directory
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: recordingsDir,
                    includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
                
                let mp4Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp4" }
                
                // Get list of files already in our broadcasts
                let existingFiles = Set(self.broadcasts.map { $0.fileURL.path })
                
                // Filter for files not already in our list
                let newFiles = mp4Files.filter { !existingFiles.contains($0.path) }
                
                if !newFiles.isEmpty {
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Found \(newFiles.count) new recordings to add")
                    }
                    
                    // Process each new file
                    for fileURL in newFiles {
                        self.processNewRecording(url: fileURL)
                    }
                }
            } catch {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Error scanning for recordings: \(error)")
                }
            }
        }
    }
    
    private func processNewRecording(url: URL) {
        let asset = AVAsset(url: url)
        
        Task {
            do {
                // Get creation date from file attributes
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Get duration
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                
                // Recording is valid if it has a positive duration
                if durationInSeconds > 0 {
                    // Create record on main thread
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        
                        let record = BroadcastRecord(
                            date: creationDate,
                            duration: durationInSeconds,
                            fileURL: url,
                            fileSize: fileSize
                        )
                        
                        // Add to list and maintain sort order
                        self.broadcasts.append(record)
                        self.broadcasts.sort { $0.date > $1.date }
                        
                        // Limit to max broadcasts
                        if self.broadcasts.count > self.maxBroadcasts {
                            // We don't delete files here, just remove from the list
                            self.broadcasts = Array(self.broadcasts.prefix(self.maxBroadcasts))
                        }
                        
                        self.saveBroadcasts()
                        
                        if Constants.FeatureFlags.enableDebugLogging {
                            print("Added new recording to broadcasts list: \(url.lastPathComponent)")
                        }
                    }
                }
            } catch {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Error processing recording: \(error)")
                }
            }
        }
    }
    
    func addExistingRecording(url: URL, duration: TimeInterval) {
        // Run this on the main thread to ensure UI updates
        DispatchQueue.main.async {
            // Check if this recording is already in our list
            if self.broadcasts.contains(where: { $0.fileURL.path == url.path }) {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Recording already in list, skipping: \(url.lastPathComponent)")
                }
                return
            }
            
            // Get file attributes
            do {
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Create record
                let record = BroadcastRecord(
                    date: creationDate,
                    duration: duration,
                    fileURL: url,
                    fileSize: fileSize
                )
                
                // Add to list and maintain sort order
                self.broadcasts.append(record)
                self.broadcasts.sort { $0.date > $1.date }
                
                // Limit to max broadcasts
                if self.broadcasts.count > self.maxBroadcasts {
                    // We don't delete files here, just remove from the list
                    self.broadcasts = Array(self.broadcasts.prefix(self.maxBroadcasts))
                }
                
                self.saveBroadcasts()
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Added broadcast to recent list: \(url.lastPathComponent)")
                }
            } catch {
                Logger.error("Failed to add existing recording: \(error)", to: Logger.app)
            }
        }
    }
    
    func deleteBroadcast(_ broadcast: BroadcastRecord) {
        do {
            // Remove from storage if it's in the Recordings directory
            if broadcast.fileURL.path.contains("/Recordings/") {
                try FileManager.default.removeItem(at: broadcast.fileURL)
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Deleted file: \(broadcast.fileURL.lastPathComponent)")
                }
            }
            
            // Update the list on the main thread to ensure UI updates
            DispatchQueue.main.async {
                self.broadcasts.removeAll { $0.id == broadcast.id }
                self.saveBroadcasts()
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Removed broadcast from list")
                }
            }
        } catch {
            Logger.error("Failed to delete broadcast: \(error)", to: Logger.app)
        }
    }
    
    func sendToServer(_ broadcast: BroadcastRecord, completion: @escaping (Bool) -> Void) {
        // This would be implemented with your server API
        // For now, just simulate success after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}
