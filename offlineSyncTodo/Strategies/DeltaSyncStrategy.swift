//
//  SyncLogger.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 27/06/2025.
//


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
            let deltaRemoteTasks: [TaskItem] = (self.testCaseType == .rq2)
                ? remoteTasks
                : remoteTasks.filter { $0.lastModified > self.lastSyncTime }

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
                    if conflictStrategy == "LWW" {
                        if remote.lastModified > local.lastModified {
                            realm.add(remote, update: .modified)
                        }
                    } else if conflictStrategy == "VV" {
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
                            let merged = ConflictResolver.resolve(local: local, remote: remote, deviceId: deviceId)
                            merged.isPendingUpload = true
                            // 🔷 確保 merged 完全寫回
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


    private func toDictionary(_ map: Map<String, Int>) -> [String: Int] {
        var dict: [String: Int] = [:]
        for entry in map {
            dict[entry.key] = entry.value
        }
        return dict
    }

    
    private func uploadLocalChanges(completion: @escaping (Int, Int) -> Void) {
        let realm = try! Realm()

        let pendingResults = realm.objects(TaskItem.self).filter(
            "isTitleModified == true OR isContentModified == true OR isPendingUpload == true"
        )

        guard !pendingResults.isEmpty else {
            completion(0, 0)
            return
        }

        /// 💡 把 Results<TaskItem> 轉成 [TaskItem]
        let pending = Array(pendingResults)

        // 提前拿 IDs 出來，等會主線程用
        let taskIds = pending.map { $0.id }

        self.repository.uploadTasks(pending) { payloadSize in
            DispatchQueue.main.async {
                do {
                    let realm = try Realm()
                    try realm.write {
                        for id in taskIds {
                            if let task = realm.object(ofType: TaskItem.self, forPrimaryKey: id) {
                                task.isPendingUpload = false
                                task.isTitleModified = false
                                task.isContentModified = false
                            }
                        }
                    }
                    
                    self.repository.fetchRemoteTasks { remoteTasks in
                        let realm = try! Realm()
                        try! realm.write {
                            for remote in remoteTasks {
                                realm.add(remote, update: .modified)
                            }
                        }
                        NotificationCenter.default.post(name: .didUpdateFromRemote, object: nil)
                        print("本地更新為遠端版本")
                    }
                    
                    completion(taskIds.count, payloadSize)
                } catch {
                    print("🔥 Realm error: \(error)")
                    completion(0, 0)
                }
            }
        }
    }

}
