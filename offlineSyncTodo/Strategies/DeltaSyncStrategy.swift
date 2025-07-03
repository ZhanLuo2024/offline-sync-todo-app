//
//  DeltaSyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//

import Foundation
import RealmSwift

class DeltaSyncStrategy: SyncStrategy {
    let repository: TaskRepository
    let deviceId: String
    let conflictStrategy: String
    let lastSyncTime: Date

    init(repository: TaskRepository, deviceId: String, conflictStrategy: String, lastSyncTime: Date) {
        self.repository = repository
        self.deviceId = deviceId
        self.conflictStrategy = conflictStrategy
        self.lastSyncTime = lastSyncTime
    }

    func sync(completion: @escaping (SyncReport) -> Void) {
        let startTime = Date()

        repository.fetchRemoteTasks { remoteTasks in
            let deltaRemoteTasks = remoteTasks.filter { $0.lastModified > self.lastSyncTime }
            let applied = self.applyRemoteTasks(deltaRemoteTasks)
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

    private func applyRemoteTasks(_ remoteTasks: [TaskItem]) {
        DispatchQueue.main.async {
            let realm = try! Realm()

            for remote in remoteTasks {
                if let local = realm.object(ofType: TaskItem.self, forPrimaryKey: remote.id) {
                    if self.conflictStrategy == "LWW" {
                        if remote.lastModified > local.lastModified {
                            try! realm.write {
                                realm.add(remote, update: .modified)
                            }
                        }
                    } else if self.conflictStrategy == "VV" {
                        let merged = ConflictResolver.resolve(local: local, remote: remote, deviceId: self.deviceId)

                        // VV 模式只要有合併過都標記為待上傳
                        merged.isTitleModified = false
                        merged.isContentModified = false
                        merged.isPendingUpload = true

                        // 判斷是否有衝突：目前策略是「title 或 content 無法判斷」視為衝突
                        let titleConflict = local.title != remote.title &&
                            ConflictResolver.compareVV(
                                local: ConflictResolver.toDictionary(local.titleVersion),
                                remote: ConflictResolver.toDictionary(remote.titleVersion)
                            ) == .concurrent


                        let contentConflict = local.content != remote.content &&
                            ConflictResolver.compareVV(
                                local: ConflictResolver.toDictionary(local.contentVersion),
                                remote: ConflictResolver.toDictionary(remote.contentVersion)
                            ) == .concurrent


                        if titleConflict || contentConflict {
                            // 加入衝突清單
                            DispatchQueue.main.async {
                                ConflictCenter.shared.addConflict(local: local, remote: remote)
                            }
                        } else {
                            // 沒衝突就直接寫入
                            try! realm.write {
                                realm.add(merged, update: .modified)
                            }
                        }
                    }
                } else {
                    // 本地不存在，新增
                    try! realm.write {
                        realm.add(remote)
                    }
                }
            }
        }
    }

    private func uploadLocalChanges(completion: @escaping (Int, Int) -> Void) {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let pending = realm.objects(TaskItem.self).filter(
                "isTitleModified == true OR isContentModified == true OR isPendingUpload == true"
            )
            let tasksToUpload = Array(pending)

            guard !tasksToUpload.isEmpty else {
                // 沒有需要上傳的
                completion(0, 0)
                return
            }

            self.repository.uploadTasks(tasksToUpload) { payloadSize in
                // 標記這些任務為已上傳
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



