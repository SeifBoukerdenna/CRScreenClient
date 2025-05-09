// BroadcastRecord.swift
import Foundation


// BroadcastRecord model
struct BroadcastRecord: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let duration: TimeInterval
    let fileURL: URL
    var fileSize: Int64 = 0
    var width: Int = 0
    var height: Int = 0
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
    
    var dimensionsFormatted: String {
        if width > 0 && height > 0 {
            return "\(width)x\(height)"
        } else {
            return "Unknown"
        }
    }
}
