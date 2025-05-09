import Foundation
import Combine
import AVFoundation

/// Manages ReplayKit broadcast state & 4‑digit code
final class BroadcastManager: ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var code: String = "— — — —"
    @Published var qualityLevel: StreamQuality = .medium
    @Published private(set) var lastRecordingURL: URL?

    private let groupID = "group.com.elmelz.crcoach"
    private let kStartedAtKey = "broadcastStartedAt"
    private let kCodeKey = "sessionCode"
    private let kQualityKey = "streamQuality"
    private var timer: AnyCancellable?
    
    // Add last known state to detect changes
    private var lastKnownBroadcastState = false

    // Use a local cache to avoid constant UserDefaults access
    private var cachedStartDate: Date?
    private var cachedCode: String?
    private var recordingsDirectory: URL?
    
    // Reference to the storage manager
    let storageManager = BroadcastStorageManager()

    private var startDate: Date? {
        // Force check UserDefaults every time to detect external changes
        if let defaults = UserDefaults(suiteName: groupID),
           let date = defaults.object(forKey: kStartedAtKey) as? Date {
            cachedStartDate = date
            return date
        }
        
        // If not in UserDefaults, clear the cache too
        cachedStartDate = nil
        return nil
    }

    init() {
        // Setup recordings directory
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: recordingsDir.path) {
                try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
            }
            
            recordingsDirectory = recordingsDir
            
            if Constants.FeatureFlags.enableDebugLogging {
                print("Recordings directory: \(recordingsDir.path)")
            }
        }
        
        // Setup initial state
        setupInitialState()
        
        // Use a faster timer to detect broadcast stop
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
            
        // Listen for quality changes to save them
        $qualityLevel
            .dropFirst() // Don't trigger on initial value
            .sink { [weak self] newQuality in
                self?.saveQualitySettings(newQuality)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupInitialState() {
        // Initialize cached values from UserDefaults
        if let defaults = UserDefaults(suiteName: groupID) {
            cachedCode = defaults.string(forKey: kCodeKey) ?? code
            code = cachedCode ?? code
            
            if let qualityString = defaults.string(forKey: kQualityKey),
               let savedQuality = StreamQuality(rawValue: qualityString) {
                qualityLevel = savedQuality
            }
            
            if let date = defaults.object(forKey: kStartedAtKey) as? Date {
                cachedStartDate = date
                isBroadcasting = true
                lastKnownBroadcastState = true
                elapsed = Date().timeIntervalSince(date)
            }
        }
    }

    func stopIfNeeded() { /* no-op until Apple exposes stop API */ }

    /// Generate & persist a new 4‑digit code
    func prepareNewCode() {
        let newCode = String(format: "%04d", Int.random(in: 0...9999))
        code = newCode
        cachedCode = newCode
        
        // Write to UserDefaults on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.set(newCode, forKey: self.kCodeKey)
        }
    }
    
    /// Save quality settings to UserDefaults
    private func saveQualitySettings(_ quality: StreamQuality) {
        if Constants.FeatureFlags.enableDebugLogging {
            print("Setting quality level to: \(quality.rawValue)")
        }
        
        // Save to UserDefaults
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.set(quality.rawValue, forKey: self.kQualityKey)
        }
    }

    private func tick() {
        // Get current state from storage (this will check UserDefaults)
        let currentDate = startDate
        let currentBroadcastState = currentDate != nil
        
        // If state changed from broadcasting to not broadcasting, handle it
        if lastKnownBroadcastState && !currentBroadcastState {
            if Constants.FeatureFlags.enableDebugLogging {
                print("Detected broadcast stopped externally")
            }
            resetBroadcastState()
        }
        
        // Update last known state
        lastKnownBroadcastState = currentBroadcastState
        
        // If broadcasting but no cached date, update it
        if isBroadcasting, cachedStartDate == nil, let date = currentDate {
            cachedStartDate = date
            elapsed = Date().timeIntervalSince(date)
        }
        // If broadcasting and have cached date, update elapsed time
        else if isBroadcasting, let s = cachedStartDate {
            elapsed = Date().timeIntervalSince(s)
        }
        // If not broadcasting, make sure elapsed is 0
        else if !isBroadcasting {
            elapsed = 0
        }
        
        // Check if we got out of sync
        if isBroadcasting != currentBroadcastState {
            isBroadcasting = currentBroadcastState
        }
    }

    // Method to reset state and find the recording
    func resetBroadcastState() {
        if Constants.FeatureFlags.enableDebugLogging {
            print("Resetting broadcast state")
        }
        
        // Get duration from cached start date if available
        var duration: TimeInterval = 0
        if let startDate = cachedStartDate {
            duration = Date().timeIntervalSince(startDate)
        }
        
        // Look for the most recent recording
        findLatestRecording { [weak self] url in
            guard let self = self else { return }
            
            if let url = url {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Found recording at: \(url.path)")
                }
                
                // Skip validation and just add the recording directly
                DispatchQueue.main.async {
                    self.lastRecordingURL = url
                    self.storageManager.addExistingRecording(url: url, duration: duration)
                    
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Added recording to storage: \(url.lastPathComponent)")
                    }
                    
                    // Force refresh the broadcasts list
                    self.storageManager.refreshBroadcasts()
                }
            } else {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("⚠️ No recording found after broadcast ended")
                    
                    // Try to scan the recordings directory directly
                    if let recordingsDir = self.recordingsDirectory {
                        do {
                            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
                            print("Files in recordings directory: \(files.map { $0.lastPathComponent })")
                        } catch {
                            print("Error listing recordings directory: \(error)")
                        }
                    }
                }
            }
        }
        
        cachedStartDate = nil
        isBroadcasting = false
        elapsed = 0
        
        // Remove from UserDefaults too
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            UserDefaults(suiteName: self.groupID)?.removeObject(forKey: self.kStartedAtKey)
        }
    }
    
    
    private func findLatestRecording(completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let recordingsDir = self.recordingsDirectory else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                // Make sure directory exists
                if !FileManager.default.fileExists(atPath: recordingsDir.path) {
                    try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Created recordings directory")
                    }
                }
                
                // Get all files in the recordings directory
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: recordingsDir,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                // Filter for MP4 files
                let mp4Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp4" }
                
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Found \(mp4Files.count) mp4 files in recordings directory")
                }
                
                if mp4Files.isEmpty {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // Sort by creation date, newest first
                let sortedFiles = try mp4Files.sorted { (url1, url2) -> Bool in
                    let attr1 = try url1.resourceValues(forKeys: [.creationDateKey])
                    let attr2 = try url2.resourceValues(forKeys: [.creationDateKey])
                    
                    guard let date1 = attr1.creationDate, let date2 = attr2.creationDate else {
                        return false
                    }
                    
                    return date1 > date2
                }
                
                // Get the most recent file
                let mostRecentFile = sortedFiles.first
                
                if let file = mostRecentFile {
                    if Constants.FeatureFlags.enableDebugLogging {
                        // Get file size
                        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        let byteCountFormatter = ByteCountFormatter()
                        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
                        byteCountFormatter.countStyle = .file
                        let readableSize = byteCountFormatter.string(fromByteCount: fileSize)
                        
                        // Get creation date
                        let fileAttributes = try file.resourceValues(forKeys: [.creationDateKey])
                        let creationDate = fileAttributes.creationDate?.description ?? "unknown"
                        
                        print("Found recording at: \(file.path)")
                        print("Recording file size: \(readableSize)")
                        print("Creation date: \(creationDate)")
                    }
                }
                
                DispatchQueue.main.async {
                    completion(mostRecentFile)
                }
            } catch {
                if Constants.FeatureFlags.enableDebugLogging {
                    print("Error finding recordings: \(error)")
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func validateRecording(url: URL, completion: @escaping (Bool, TimeInterval?, Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            
            // Check duration and tracks
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let durationInSeconds = CMTimeGetSeconds(duration)
                    
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    let trackCount = tracks.count
                    
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Recording details: Duration \(durationInSeconds)s, Video tracks: \(trackCount)")
                    }
                    
                    // Recording is valid if it has a positive duration and at least one video track
                    let isValid = durationInSeconds > 0 && trackCount > 0
                    
                    DispatchQueue.main.async {
                        completion(isValid, durationInSeconds, trackCount)
                    }
                } catch {
                    if Constants.FeatureFlags.enableDebugLogging {
                        print("Error validating recording: \(error)")
                    }
                    DispatchQueue.main.async {
                        completion(false, nil, 0)
                    }
                }
            }
        }
    }
}
