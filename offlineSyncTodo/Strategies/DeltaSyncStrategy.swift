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

        if testCaseType == .rq1 {
            markLocalTasksForUpload()
        } else {
            print("RQ2:rely on user edits.")
        }

        repository.fetchRemoteTasks { remoteTasks in
            let deltaRemoteTasks: [TaskItem]
            if self.testCaseType == .rq2 {
                deltaRemoteTasks = remoteTasks
            } else {
                deltaRemoteTasks = remoteTasks.filter { $0.lastModified > self.lastSyncTime }
            }

            self.applyRemoteTasks(deltaRemoteTasks)
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

    // Automatically marks a gradient number of local tasks as modified (only for RQ1)
    private func markLocalTasksForUpload() {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let allTasks = realm.objects(TaskItem.self)
            guard !allTasks.isEmpty else { return }

            let total = allTasks.count

            let countToModify: Int
            switch total {
            case 0..<50:
                countToModify = min(5, total)
            case 50..<101:
                countToModify = min(10, total)
            case 100..<501:
                countToModify = min(50, total)
            default:
                countToModify = min(100, total)
            }

            let shuffled = Array(allTasks).shuffled()
            let tasksToMark = shuffled.prefix(countToModify)

            try! realm.write {
                for task in tasksToMark {
                    task.title += " (modified)"
                    task.lastModified = Date()
                    task.isPendingUpload = true
                }
            }

            print("Marked \(countToModify) of \(total) tasks as modified for delta sync (RQ1).")
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

                        merged.isTitleModified = false
                        merged.isContentModified = false
                        merged.isPendingUpload = true

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
                            DispatchQueue.main.async {
                                ConflictCenter.shared.addConflict(local: local, remote: remote)
                            }
                        } else {
                            try! realm.write {
                                realm.add(merged, update: .modified)
                            }
                        }
                    }
                } else {
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

