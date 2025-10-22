import Foundation
import CoreData

public class StorageService: ObservableObject {
    public static let shared = StorageService()
    
    // Temporary in-memory storage with persistence to UserDefaults
    private var rules: [Rule] = []
    private var events: [MonitoringEvent] = []
    
    public var context: NSManagedObjectContext? {
        return nil // No Core Data context for now
    }
    
    private init() {
        loadFromUserDefaults()
        print("StorageService initialized with persistent storage")
    }
    
    public func save() {
        saveToUserDefaults()
        print("Data saved to UserDefaults")
    }
    
    public func saveRule(_ rule: Rule) {
        // Remove existing rule with same ID
        rules.removeAll { $0.id == rule.id }
        // Add new rule
        rules.append(rule)
        save()
        print("Saved rule: \(rule.description)")
    }
    
    public func loadRules() -> [Rule] {
        print("Loaded \(rules.count) rules from persistent storage")
        return rules
    }
    
    public func saveEvent(_ event: MonitoringEvent) {
        events.append(event)
        // Keep only last 100 events to prevent memory issues
        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }
        save()
        print("Saved event: \(event.type.rawValue)")
    }
    
    public func loadEvents(limit: Int = 50) -> [MonitoringEvent] {
        let limitedEvents = Array(events.suffix(limit))
        print("Loaded \(limitedEvents.count) events from persistent storage")
        return limitedEvents
    }
    
    // MARK: - UserDefaults Persistence
    
    private func saveToUserDefaults() {
        do {
            let rulesData = try JSONEncoder().encode(rules)
            let eventsData = try JSONEncoder().encode(events)
            
            UserDefaults.standard.set(rulesData, forKey: "KidGuardAI_Rules")
            UserDefaults.standard.set(eventsData, forKey: "KidGuardAI_Events")
            
            print("Data persisted to UserDefaults")
        } catch {
            print("Failed to save to UserDefaults: \(error)")
        }
    }
    
    private func loadFromUserDefaults() {
        do {
            if let rulesData = UserDefaults.standard.data(forKey: "KidGuardAI_Rules") {
                rules = try JSONDecoder().decode([Rule].self, from: rulesData)
                print("Loaded \(rules.count) rules from UserDefaults")
            }
            
            if let eventsData = UserDefaults.standard.data(forKey: "KidGuardAI_Events") {
                events = try JSONDecoder().decode([MonitoringEvent].self, from: eventsData)
                print("Loaded \(events.count) events from UserDefaults")
            }
        } catch {
            print("Failed to load from UserDefaults: \(error)")
            rules = []
            events = []
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}