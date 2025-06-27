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
            self.uploadLocalChanges { itemsSent in
                let report = SyncReport(
                    itemsSent: itemsSent,
                    itemsReceived: deltaRemoteTasks.count,
                    duration: Date().timeIntervalSince(startTime)
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
                        let resolved = ConflictResolver.resolve(local: local, remote: remote, deviceId: self.deviceId)
                        if resolved != local {
                            try! realm.write {
                                realm.add(resolved, update: .modified)
                            }
                        } else {
                            DispatchQueue.main.async {
                                ConflictCenter.shared.addConflict(local: local, remote: remote)
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

    private func uploadLocalChanges(completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let pending = realm.objects(TaskItem.self).filter("isTitleModified == true OR isContentModified == true")
            let tasksToUpload = Array(pending)
            let count = tasksToUpload.count
            self.repository.uploadTasks(tasksToUpload) {
                completion(count)
            }
        }
    }
}

class ConflictCenter: ObservableObject {
    static let shared = ConflictCenter()
    private init() {}

    @Published var conflicts: [(local: TaskItem, remote: TaskItem)] = []

    func addConflict(local: TaskItem, remote: TaskItem) {
        conflicts.append((local, remote))
    }

    func clear() {
        conflicts.removeAll()
    }
}

