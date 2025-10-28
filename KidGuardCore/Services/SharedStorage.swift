import Foundation

public class SharedStorage {
    public static let appGroupIdentifier = "group.com.kidguardai.shared"
    
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    public static var rulesURL: URL? {
        containerURL?.appendingPathComponent("rules.json")
    }
    
    public static var eventsURL: URL? {
        containerURL?.appendingPathComponent("events.log")
    }
    
    public static var timestampURL: URL? {
        containerURL?.appendingPathComponent("rules-timestamp.txt")
    }
    
    // MARK: - Rules Management
    
    public static func saveRules(_ rules: [Rule]) throws {
        guard let url = rulesURL else {
            throw SharedStorageError.noContainer
        }
        
        let data = try JSONEncoder().encode(rules)
        try data.write(to: url, options: .atomic)
        
        // Update timestamp to signal rule changes
        updateRulesTimestamp()
        
        print("SharedStorage: Saved \(rules.count) rules to App Group")
    }
    
    public static func loadRules() throws -> [Rule] {
        guard let url = rulesURL else {
            throw SharedStorageError.noContainer
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("SharedStorage: No rules file found, returning empty array")
            return []
        }
        
        let data = try Data(contentsOf: url)
        let rules = try JSONDecoder().decode([Rule].self, from: data)
        
        print("SharedStorage: Loaded \(rules.count) rules from App Group")
        return rules
    }
    
    // MARK: - Events Management
    
    public static func appendEvent(_ event: NetworkFilterEvent) throws {
        guard let url = eventsURL else {
            throw SharedStorageError.noContainer
        }
        
        let eventString = formatEvent(event)
        let data = (eventString + "\n").data(using: .utf8)!
        
        if FileManager.default.fileExists(atPath: url.path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try fileHandle.close()
        } else {
            try data.write(to: url)
        }
        
        // Rotate log if it gets too large
        try rotateLogIfNeeded(url: url)
    }
    
    public static func loadEvents() throws -> [NetworkFilterEvent] {
        guard let url = eventsURL else {
            throw SharedStorageError.noContainer
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        return lines.compactMap { parseEvent($0) }
    }
    
    public static func clearEvents() throws {
        guard let url = eventsURL else {
            throw SharedStorageError.noContainer
        }
        
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Timestamp Management
    
    public static func updateRulesTimestamp() {
        guard let url = timestampURL else { return }
        
        let timestamp = String(Date().timeIntervalSince1970)
        try? timestamp.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public static func getRulesTimestamp() -> TimeInterval {
        guard let url = timestampURL,
              let timestampString = try? String(contentsOf: url),
              let timestamp = TimeInterval(timestampString) else {
            return 0
        }
        return timestamp
    }
    
    // MARK: - Private Helpers
    
    private static func formatEvent(_ event: NetworkFilterEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return "\(formatter.string(from: event.timestamp))|\(event.action)|\(event.hostname)|\(event.sourceApp)|\(event.ruleDescription)"
    }
    
    private static func parseEvent(_ line: String) -> NetworkFilterEvent? {
        let components = line.components(separatedBy: "|")
        guard components.count == 5 else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let timestamp = formatter.date(from: components[0]),
              let action = NetworkFilterAction(rawValue: components[1]) else {
            return nil
        }
        
        return NetworkFilterEvent(
            timestamp: timestamp,
            action: action,
            hostname: components[2],
            sourceApp: components[3],
            ruleDescription: components[4]
        )
    }
    
    private static func rotateLogIfNeeded(url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Rotate if log is larger than 1MB
        if fileSize > 1_000_000 {
            let backupURL = url.appendingPathExtension("backup")
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.moveItem(at: url, to: backupURL)
            
            print("SharedStorage: Rotated log file (was \(fileSize) bytes)")
        }
    }
}

// MARK: - Supporting Types

public struct NetworkFilterEvent {
    public let timestamp: Date
    public let action: NetworkFilterAction
    public let hostname: String
    public let sourceApp: String
    public let ruleDescription: String
    
    public init(timestamp: Date, action: NetworkFilterAction, hostname: String, sourceApp: String, ruleDescription: String) {
        self.timestamp = timestamp
        self.action = action
        self.hostname = hostname
        self.sourceApp = sourceApp
        self.ruleDescription = ruleDescription
    }
}

public enum NetworkFilterAction: String, CaseIterable {
    case blocked = "blocked"
    case allowed = "allowed"
}

public enum SharedStorageError: Error {
    case noContainer
    case fileNotFound
    case invalidData
}