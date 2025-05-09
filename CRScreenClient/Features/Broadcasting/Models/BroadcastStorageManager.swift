import Foundation
import AVFoundation

class BroadcastStorageManager: ObservableObject {
    @Published private(set) var broadcasts: [BroadcastRecord] = []
    
    private let maxBroadcasts = 10
    private let storageKey = "recentBroadcasts"
    private let groupID = "group.com.elmelz.crcoach"
    
    // Set to track files we've already processed to prevent duplicates
    private var processedFilePaths = Set<String>()
    
    init() {
        loadBroadcasts()
        
        // After loading, populate the processed files set
        processedFilePaths = Set(broadcasts.map { $0.fileURL.path })
        
        scanForMissingRecordings()
    }
    
    private func loadBroadcasts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            var decodedBroadcasts = try JSONDecoder().decode([BroadcastRecord].self, from: data)
            
            // Filter out broadcasts whose files don't exist anymore
            decodedBroadcasts = decodedBroadcasts.filter { record in
                FileManager.default.fileExists(atPath: record.fileURL.path)
            }
            
            // Deduplicate based on file path - this is crucial!
            var uniquePathsSet = Set<String>()
            decodedBroadcasts = decodedBroadcasts.filter { record in
                let path = record.fileURL.path
                if uniquePathsSet.contains(path) {
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Removing duplicate entry for: \(record.fileURL.lastPathComponent)")
                    }
                    return false
                }
                uniquePathsSet.insert(path)
                return true
            }
            
            // Update file sizes
            decodedBroadcasts = decodedBroadcasts.map { record in
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
            decodedBroadcasts.sort { $0.date > $1.date }
            
            // Apply the deduplicated, filtered list
            broadcasts = decodedBroadcasts
            
            if Constants.FeatureFlags.enableDebugLogging {
                print("Loaded \(broadcasts.count) broadcasts from storage")
            }
            
        } catch {
            Logger.error("Failed to load broadcasts: \(error)", to: Logger.app)
        }
    }
    
    private func saveBroadcasts() {
        do {
            let data = try JSONEncoder().encode(broadcasts)
            UserDefaults.standard.set(data, forKey: storageKey)
            
            // Update processed files set
            processedFilePaths = Set(broadcasts.map { $0.fileURL.path })
            
            if Constants.FeatureFlags.enableDebugLogging {
                print("Saved \(broadcasts.count) broadcasts to storage")
            }
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
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Found \(mp4Files.count) mp4 files in recordings directory")
                }
                
                // Filter for files not already in our tracking set
                let newFiles = mp4Files.filter { !self.processedFilePaths.contains($0.path) }
                
                if !newFiles.isEmpty {
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Found \(newFiles.count) new recordings to add")
                    }
                    
                    // Process each new file
                    for fileURL in newFiles {
                        // Add to processed files immediately to prevent duplicate processing
                        DispatchQueue.main.async {
                            self.processedFilePaths.insert(fileURL.path)
                        }
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
        let asset = AVURLAsset(url: url)
        
        Task {
            do {
                // Get creation date from file attributes
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Get duration and dimensions
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                
                // Get video dimensions
                let tracks = try await asset.loadTracks(withMediaType: .video)
                
                // Use local variables for dimensions to avoid concurrency issues
                let trackDimensions: CGSize = if let videoTrack = tracks.first {
                    try await videoTrack.load(.naturalSize)
                } else {
                    CGSize.zero
                }
                
                let videoWidth = Int(trackDimensions.width)
                let videoHeight = Int(trackDimensions.height)
                
                if Constants.FeatureFlags.enableDebugLogging && trackDimensions != .zero {
                    print("Video dimensions: \(videoWidth)x\(videoHeight)")
                }
                
                // Check again if path has been processed already (could have happened in another concurrent task)
                let filePath = url.path
                
                // Instead of using a local variable that we modify, directly return if already processed
                let isAlreadyInList = await MainActor.run { () -> Bool in
                    let alreadyProcessed = self.broadcasts.contains { $0.fileURL.path == filePath }
                    if alreadyProcessed && Constants.FeatureFlags.enableDebugLogging {
                        print("Skipping already processed file: \(url.lastPathComponent)")
                    }
                    return alreadyProcessed
                }
                
                if isAlreadyInList {
                    return
                }
                
                // Recording is valid if it has a positive duration
                if durationInSeconds > 0 {
                    // Create record on main thread
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        
                        let record = BroadcastRecord(
                            date: creationDate,
                            duration: durationInSeconds,
                            fileURL: url,
                            fileSize: fileSize,
                            width: videoWidth,
                            height: videoHeight
                        )
                        
                        // Check one more time for duplicates
                        guard !self.broadcasts.contains(where: { $0.fileURL.path == url.path }) else {
                            return
                        }
                        
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
            // Skip if already in processed files
            guard !self.processedFilePaths.contains(url.path) else {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Skipping already processed file: \(url.lastPathComponent)")
                }
                return
            }
            
            // Add to processed files set immediately to prevent duplicates
            self.processedFilePaths.insert(url.path)
            
            // Skip if already in broadcasts list
            guard !self.broadcasts.contains(where: { $0.fileURL.path == url.path }) else {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Recording already in list, skipping: \(url.lastPathComponent)")
                }
                return
            }
            
            if Constants.FeatureFlags.enableDebugLogging {
                print("Added recording to storage: \(url.lastPathComponent)")
            }
            
            // Process the recording asynchronously
            Task {
                do {
                    // Get file attributes
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    // Get video dimensions
                    let asset = AVURLAsset(url: url)
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    
                    // Use local variables for dimensions to avoid concurrency issues
                    let trackDimensions: CGSize = if let videoTrack = tracks.first {
                        try await videoTrack.load(.naturalSize)
                    } else {
                        CGSize.zero
                    }
                    
                    let videoWidth = Int(trackDimensions.width)
                    let videoHeight = Int(trackDimensions.height)
                    
                    // Verify duration if not provided
                    var finalDuration = duration
                    if finalDuration <= 0 {
                        let assetDuration = try await asset.load(.duration)
                        finalDuration = assetDuration.seconds
                    }
                    
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Video info - Dimensions: \(videoWidth)x\(videoHeight), Duration: \(finalDuration)s, Size: \(fileSize) bytes")
                    }
                    
                    // Create record with all info
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        
                        // Check one more time to prevent duplicates
                        guard !self.broadcasts.contains(where: { $0.fileURL.path == url.path }) else {
                            return
                        }
                        
                        // Create record
                        let record = BroadcastRecord(
                            date: creationDate,
                            duration: finalDuration,
                            fileURL: url,
                            fileSize: fileSize,
                            width: videoWidth,
                            height: videoHeight
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
                    }
                } catch {
                    Logger.error("Failed to add existing recording: \(error)", to: Logger.app)
                    
                    // Create a basic record without dimensions if there was an error
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        
                        do {
                            // Check for duplicates one more time
                            guard !self.broadcasts.contains(where: { $0.fileURL.path == url.path }) else {
                                return
                            }
                            
                            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                            let creationDate = resourceValues.creationDate ?? Date()
                            
                            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            
                            let record = BroadcastRecord(
                                date: creationDate,
                                duration: duration > 0 ? duration : 0,
                                fileURL: url,
                                fileSize: fileSize
                            )
                            
                            self.broadcasts.append(record)
                            self.broadcasts.sort { $0.date > $1.date }
                            
                            if self.broadcasts.count > self.maxBroadcasts {
                                self.broadcasts = Array(self.broadcasts.prefix(self.maxBroadcasts))
                            }
                            
                            self.saveBroadcasts()
                            
                            if Constants.FeatureFlags.enableDebugLogging {
                                print("Added basic broadcast record (without dimensions) to list: \(url.lastPathComponent)")
                            }
                        } catch {
                            Logger.error("Failed to create basic record: \(error)", to: Logger.app)
                        }
                    }
                }
            }
        }
    }
    
    func deleteBroadcast(_ broadcast: BroadcastRecord) {
        // First remove from list regardless of whether the file deletion succeeds
        DispatchQueue.main.async {
            // Remove all instances with this file path
            self.broadcasts.removeAll { $0.fileURL.path == broadcast.fileURL.path }
            self.saveBroadcasts() // This updates processedFilePaths as well
            
            if Constants.FeatureFlags.enableDebugLogging {
                print("Removed broadcast(s) with path: \(broadcast.fileURL.path)")
            }
        }
        
        // Then try to delete the file
        do {
            // Check if file exists before trying to remove
            if FileManager.default.fileExists(atPath: broadcast.fileURL.path) {
                try FileManager.default.removeItem(at: broadcast.fileURL)
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Deleted file: \(broadcast.fileURL.lastPathComponent)")
                }
            } else {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("File already deleted: \(broadcast.fileURL.lastPathComponent)")
                }
            }
        } catch {
            Logger.error("Failed to delete broadcast file: \(error)", to: Logger.app)
            // We already removed from list, so no need for further action
        }
    }
    
    func sendToServer(_ broadcast: BroadcastRecord, completion: @escaping (Bool) -> Void) {
        // This would be implemented with your server API
        // For now, just simulate success after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            DispatchQueue.main.async {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Simulated sending recording to server: \(broadcast.fileURL.lastPathComponent)")
                }
                completion(true)
            }
        }
    }
    
    // Helper method to extract timestamp from filename
    private func getTimestampFromFilename(_ filename: String) -> Date? {
        // Handle format like broadcast_20230516_123045.mp4 or broadcast_1746767572.406355.mp4
        
        // First try the YYYYMMDD_HHMMSS format
        if let dateString = filename.split(separator: "_").dropFirst().first,
           let timeString = filename.split(separator: "_").dropFirst().dropFirst().first?.split(separator: ".").first {
            let fullString = "\(dateString)_\(timeString)"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            if let date = dateFormatter.date(from: String(fullString)) {
                return date
            }
        }
        
        // Try the timestamp format
        if let timestampString = filename.split(separator: "_").dropFirst().first?.split(separator: ".").first,
           let timestamp = Double(timestampString) {
            return Date(timeIntervalSince1970: timestamp)
        }
        
        return nil
    }
}
