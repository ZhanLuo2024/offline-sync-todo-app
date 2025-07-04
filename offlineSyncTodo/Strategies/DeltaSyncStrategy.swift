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

        markLocalTasksForUpload()

        repository.fetchRemoteTasks { remoteTasks in
            let deltaRemoteTasks = remoteTasks.filter { $0.lastModified > self.lastSyncTime }
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

    // Automatically marks a gradient number of local tasks as modified (based on total count)
    private func markLocalTasksForUpload() {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let allTasks = realm.objects(TaskItem.self)
            guard !allTasks.isEmpty else { return }

            let total = allTasks.count

            // Determine how many to mark based on gradient thresholds
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

            // Randomly pick tasks and mark as modified
            let shuffled = Array(allTasks).shuffled()
            let tasksToMark = shuffled.prefix(countToModify)

            try! realm.write {
                for task in tasksToMark {
                    task.title += " (modified)"
                    task.lastModified = Date()
                    task.isPendingUpload = true
                }
            }

            print("Marked \(countToModify) of \(total) tasks as modified for delta sync.")
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

                        // VV mode always marks merged tasks for upload
                        merged.isTitleModified = false
                        merged.isContentModified = false
                        merged.isPendingUpload = true

                        // Detect conflict if VV vectors are concurrent
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
                            // Add to conflict list
                            DispatchQueue.main.async {
                                ConflictCenter.shared.addConflict(local: local, remote: remote)
                            }
                        } else {
                            // No conflict, write merged task
                            try! realm.write {
                                realm.add(merged, update: .modified)
                            }
                        }
                    }
                } else {
                    // Local task doesn't exist, insert new
                    try! realm.write {
                        realm.add(remote)
                    }
                }
            }
        }
    }

    /// Uploads all pending tasks to the server
    private func uploadLocalChanges(completion: @escaping (Int, Int) -> Void) {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let pending = realm.objects(TaskItem.self).filter(
                "isTitleModified == true OR isContentModified == true OR isPendingUpload == true"
            )
            let tasksToUpload = Array(pending)

            guard !tasksToUpload.isEmpty else {
                // Nothing to upload
                completion(0, 0)
                return
            }

            self.repository.uploadTasks(tasksToUpload) { payloadSize in
                // Mark tasks as uploaded
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
