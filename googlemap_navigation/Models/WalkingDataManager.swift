import Foundation
import CoreData
import Firebase
import FirebaseFirestore

class WalkingDataManager {
    static let shared = WalkingDataManager()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private var syncTimer: Timer?
    private var syncInterval: TimeInterval = 604800 // 默认一周
    
    // MARK: - CoreData
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WalkingData")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        startSyncTimer()
    }
    
    // MARK: - Timer Management
    func setSyncInterval(_ interval: TimeInterval) {
        syncInterval = interval
        stopSyncTimer()
        startSyncTimer()
    }
    
    func setSyncIntervalInDays(_ days: Double) {
        setSyncInterval(days * 24 * 3600)
    }
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.syncLocalSessions()
            }
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - CoreData Operations
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    // MARK: - Walking Session Operations
    
    /// 创建新的步行会话
    func createWalkingSession(id: String = UUID().uuidString,
                            date: Date = Date(),
                            steps: Int32,
                            duration: Double,
                            totalDistance: Double,
                            averageSpeed: Double) -> WalkingSession {
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
    
    /// 获取所有步行会话
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
    
    /// 获取最近的步行会话
    func fetchRecentWalkingSessions(limit: Int = 10) -> [WalkingSession] {
        let request: NSFetchRequest<WalkingSession> = WalkingSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recent walking sessions: \(error)")
            return []
        }
    }
    
    /// 获取特定日期范围内的步行会话
    func fetchWalkingSessions(from startDate: Date, to endDate: Date) -> [WalkingSession] {
        let request: NSFetchRequest<WalkingSession> = WalkingSession.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching walking sessions by date range: \(error)")
            return []
        }
    }
    
    /// 删除步行会话
    func deleteSession(_ session: WalkingSession) {
        context.delete(session)
        saveContext()
    }
    
    // MARK: - Firebase Operations
    
    /// 保存步行会话到 Firebase
    private func saveToFirebase(_ session: WalkingSession) async throws {
        let data: [String: Any] = [
            "id": session.id ?? UUID().uuidString,
            "date": session.date ?? Date(),
            "steps": session.steps,
            "duration": session.duration,
            "totalDistance": session.totalDistance,
            "averageSpeed": session.averageSpeed
        ]
        
        try await db.collection("walking_sessions").document(session.id ?? UUID().uuidString).setData(data)
    }
    
    /// 从 Firebase 获取步行会话
    private func fetchFromFirebase() async throws -> [[String: Any]] {
        let snapshot = try await db.collection("walking_sessions")
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    // MARK: - Sync Operations
    
    /// 同步本地未同步的会话到 Firebase
    private func syncLocalSessions() async {
        let unsyncedSessions = fetchUnsyncedSessions()
        
        for session in unsyncedSessions {
            do {
                try await saveToFirebase(session)
                markSessionAsSynced(session)
            } catch {
                print("Error syncing session: \(error)")
            }
        }
    }
    
    /// 从 Firebase 同步数据到本地
    func syncFromCloud() async {
        do {
            let cloudSessions = try await fetchFromFirebase()
            let localSessions = fetchAllWalkingSessions()
            let localSessionIds = Set(localSessions.compactMap { $0.id })
            
            for sessionData in cloudSessions {
                guard let id = sessionData["id"] as? String,
                      !localSessionIds.contains(id) else { continue }
                
                let session = createWalkingSession(
                    id: id,
                    date: (sessionData["date"] as? Timestamp)?.dateValue() ?? Date(),
                    steps: Int32(sessionData["steps"] as? Int ?? 0),
                    duration: sessionData["duration"] as? Double ?? 0.0,
                    totalDistance: sessionData["totalDistance"] as? Double ?? 0.0,
                    averageSpeed: sessionData["averageSpeed"] as? Double ?? 0.0
                )
                markSessionAsSynced(session)
            }
        } catch {
            print("Error syncing from cloud: \(error)")
        }
    }
    
    /// 获取未同步的会话
    private func fetchUnsyncedSessions() -> [WalkingSession] {
        let request: NSFetchRequest<WalkingSession> = WalkingSession.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == NO")
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching unsynced sessions: \(error)")
            return []
        }
    }
    
    /// 标记会话为已同步
    private func markSessionAsSynced(_ session: WalkingSession) {
        session.isSynced = true
        saveContext()
    }
    
    /// 立即执行一次同步
    func syncNow() {
        Task {
            await syncLocalSessions()
        }
    }
    
    // MARK: - Statistics
    
    /// 获取总步数
    func getTotalSteps() -> Int32 {
        let sessions = fetchAllWalkingSessions()
        return sessions.reduce(0) { $0 + $1.steps }
    }
    
    /// 获取总距离
    func getTotalDistance() -> Double {
        let sessions = fetchAllWalkingSessions()
        return sessions.reduce(0) { $0 + $1.totalDistance }
    }
    
    /// 获取平均速度
    func getAverageSpeed() -> Double {
        let sessions = fetchAllWalkingSessions()
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.averageSpeed } / Double(sessions.count)
    }
    
    /// 获取今日步数
    func getTodaySteps() -> Int32 {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let sessions = fetchWalkingSessions(from: today, to: tomorrow)
        return sessions.reduce(0) { $0 + $1.steps }
    }
} 