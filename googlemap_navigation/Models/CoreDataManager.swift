import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WalkingData")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    // MARK: - Walking Session Operations
    
    func createWalkingSession(id: String, date: Date, steps: Int32, duration: Double, totalDistance: Double, averageSpeed: Double) -> WalkingSession {
        let session = WalkingSession(context: context)
        session.id = id
        session.date = date
        session.steps = steps
        session.duration = duration
        session.totalDistance = totalDistance
        session.averageSpeed = averageSpeed
        session.isSynced = false
        saveContext()
        return session
    }
    
    func fetchAllWalkingSessions() -> [WalkingSession] {
        let request: NSFetchRequest<WalkingSession> = WalkingSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching walking sessions: \(error)")
            return []
        }
    }
    
    func fetchUnsyncedSessions() -> [WalkingSession] {
        let request: NSFetchRequest<WalkingSession> = WalkingSession.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == NO")
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching unsynced sessions: \(error)")
            return []
        }
    }
    
    func markSessionAsSynced(_ session: WalkingSession) {
        session.isSynced = true
        saveContext()
    }
    
    func deleteSession(_ session: WalkingSession) {
        context.delete(session)
        saveContext()
    }
} 