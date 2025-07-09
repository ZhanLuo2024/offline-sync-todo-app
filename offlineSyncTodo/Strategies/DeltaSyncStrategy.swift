import Foundation
import RealmSwift

class DeltaSyncStrategy: SyncStrategy {
    let repository: TaskRepository
    let deviceId: String
    let conflictStrategy: String
    let lastSyncTime: Date
    let testCaseType: TestCaseType

    init(repository: TaskRepository,
         deviceId: String,
         conflictStrategy: String,
         lastSyncTime: Date,
         testCaseType: TestCaseType) {
        self.repository = repository
        self.deviceId = deviceId
        self.conflictStrategy = conflictStrategy
        self.lastSyncTime = lastSyncTime
        self.testCaseType = testCaseType
    }

    func sync(completion: @escaping (SyncReport) -> Void) {
        let startTime = Date()
        
        repository.fetchRemoteTasks { remoteTasks in
            var deltaRemoteTasks: [TaskItem]
            if self.testCaseType == .rq2 {
                deltaRemoteTasks = remoteTasks
            } else {
                deltaRemoteTasks = remoteTasks.filter { $0.lastModified > self.lastSyncTime }
            }

            let hasConflict = self.applyRemoteTasks(deltaRemoteTasks)

            if hasConflict {
                print("檢測到未解決衝突，終止上傳")
                completion(SyncReport(itemsSent: 0, itemsReceived: 0, duration: 0, payloadSize: 0))
                return
            }

            self.uploadLocalChanges { itemsSent, payloadSize in
                let report = SyncReport(
                    itemsSent: itemsSent,
                    itemsReceived: deltaRemoteTasks.count,
                    duration: Date().timeIntervalSince(startTime),
                    payloadSize: payloadSize
                )
                completion(report)
            }
        }
    }

    private func applyRemoteTasks(_ remoteTasks: [TaskItem]) -> Bool {
        var foundConflict = false

        let realm = try! Realm()
        try! realm.write {
            for remote in remoteTasks {
                if let local = realm.object(ofType: TaskItem.self, forPrimaryKey: remote.id) {
                    if self.conflictStrategy == "LWW" {
                        if remote.lastModified > local.lastModified {
                            realm.add(remote, update: .modified)
                        }
                    } else if self.conflictStrategy == "VV" {
                        let merged = local
                        
                        let titleConflict =
                            local.title != remote.title &&
                            ConflictResolver.compareVV(
                                local: ConflictResolver.toDictionary(local.titleVersion),
                                remote: ConflictResolver.toDictionary(remote.titleVersion)
                            ) == .concurrent
                        
                        let contentConflict =
                            local.content != remote.content &&
                            ConflictResolver.compareVV(
                                local: ConflictResolver.toDictionary(local.contentVersion),
                                remote: ConflictResolver.toDictionary(remote.contentVersion)
                            ) == .concurrent
                        
                        if titleConflict || contentConflict {
                            ConflictCenter.shared.addConflict(local: local, remote: remote)
                            foundConflict = true
                        } else {
                            merged.isTitleModified = false
                            merged.isContentModified = false
                            merged.isPendingUpload = true
                            realm.add(merged, update: .modified)
                        }
                    }
                } else {
                    realm.add(remote, update: .modified)
                }
            }
        }

        return foundConflict
    }

    private func uploadLocalChanges(completion: @escaping (Int, Int) -> Void) {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let pending = realm.objects(TaskItem.self).filter(
                "isTitleModified == true OR isContentModified == true OR isPendingUpload == true"
            )
            let tasksToUpload = Array(pending)

            guard !tasksToUpload.isEmpty else {
                completion(0, 0)
                return
            }

            self.repository.uploadTasks(tasksToUpload) { payloadSize in
                try! realm.write {
                    for task in tasksToUpload {
                        task.isPendingUpload = false
                        task.isTitleModified = false
                        task.isContentModified = false
                    }
                }
                completion(tasksToUpload.count, payloadSize)
            }
        }
    }
}
