import Foundation
import CoreData

public class StorageService: ObservableObject {
    public static let shared = StorageService()
    
    private let container: NSPersistentContainer
    
    public var context: NSManagedObjectContext {
        container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: "KidGuardAI")
        
        // Configure for encrypted storage
        let storeURL = getDocumentsDirectory().appendingPathComponent("KidGuardAI.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    public func save() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    public func saveRule(_ rule: Rule) {
        let ruleEntity = RuleEntity(context: context)
        ruleEntity.id = rule.id
        ruleEntity.ruleDescription = rule.description
        ruleEntity.categories = rule.categories.joined(separator: ",")
        ruleEntity.actions = rule.actions.map { $0.rawValue }.joined(separator: ",")
        ruleEntity.severity = rule.severity.rawValue
        ruleEntity.isActive = rule.isActive
        ruleEntity.createdAt = rule.createdAt
        
        save()
    }
    
    public func loadRules() -> [Rule] {
        let request: NSFetchRequest<RuleEntity> = RuleEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let description = entity.ruleDescription,
                      let categoriesString = entity.categories,
                      let actionsString = entity.actions,
                      let severity = RuleSeverity(rawValue: entity.severity ?? "medium"),
                      let createdAt = entity.createdAt else {
                    return nil
                }
                
                let categories = categoriesString.components(separatedBy: ",")
                let actions = actionsString.components(separatedBy: ",").compactMap { RuleAction(rawValue: $0) }
                
                return Rule(
                    id: id,
                    description: description,
                    categories: categories,
                    actions: actions,
                    severity: severity,
                    isActive: entity.isActive,
                    createdAt: createdAt
                )
            }
        } catch {
            print("Failed to load rules: \(error)")
            return []
        }
    }
    
    public func saveEvent(_ event: MonitoringEvent) {
        let eventEntity = EventEntity(context: context)
        eventEntity.id = event.id
        eventEntity.timestamp = event.timestamp
        eventEntity.type = event.type.rawValue
        eventEntity.url = event.url
        eventEntity.content = event.content
        eventEntity.screenshotPath = event.screenshotPath
        eventEntity.ruleViolated = event.ruleViolated
        eventEntity.action = event.action.rawValue
        eventEntity.severity = event.severity.rawValue
        eventEntity.processed = event.processed
        
        save()
    }
    
    public func loadEvents(limit: Int = 100) -> [MonitoringEvent] {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let timestamp = entity.timestamp,
                      let typeString = entity.type,
                      let type = EventType(rawValue: typeString),
                      let actionString = entity.action,
                      let action = RuleAction(rawValue: actionString),
                      let severityString = entity.severity,
                      let severity = RuleSeverity(rawValue: severityString) else {
                    return nil
                }
                
                return MonitoringEvent(
                    id: id,
                    timestamp: timestamp,
                    type: type,
                    url: entity.url,
                    content: entity.content,
                    screenshotPath: entity.screenshotPath,
                    ruleViolated: entity.ruleViolated,
                    action: action,
                    severity: severity,
                    processed: entity.processed
                )
            }
        } catch {
            print("Failed to load events: \(error)")
            return []
        }
    }
    
    public func cleanupOldEvents(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            save()
        } catch {
            print("Failed to cleanup old events: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KidGuardAI")
    }
}

// Core Data Entities would be defined in a .xcdatamodeld file
// For now, we'll create simple NSManagedObject subclasses

import CoreData

@objc(RuleEntity)
public class RuleEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var ruleDescription: String?
    @NSManaged public var categories: String?
    @NSManaged public var actions: String?
    @NSManaged public var severity: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
}

@objc(EventEntity)
public class EventEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var type: String?
    @NSManaged public var url: String?
    @NSManaged public var content: String?
    @NSManaged public var screenshotPath: String?
    @NSManaged public var ruleViolated: UUID?
    @NSManaged public var action: String?
    @NSManaged public var severity: String?
    @NSManaged public var processed: Bool
}