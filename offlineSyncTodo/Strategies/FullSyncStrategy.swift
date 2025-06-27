//
//  FullSyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift

class FullSyncStrategy: SyncStrategy {
    let repository: TaskRepository
    let deviceId: String
    let conflictStrategy: String

    init(repository: TaskRepository, deviceId: String, conflictStrategy: String) {
        self.repository = repository
        self.deviceId = deviceId
        self.conflictStrategy = conflictStrategy
    }

    func sync(completion: @escaping (SyncReport) -> Void) {
        let startTime = Date()

        repository.fetchRemoteTasks { remoteTasks in
            self.applyRemoteTasks(remoteTasks)
            self.uploadLocalChanges { itemsSent in
                let report = SyncReport(
                    itemsSent: itemsSent,
                    itemsReceived: remoteTasks.count,
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
                    if remote.lastModified > local.lastModified {
                        try! realm.write {
                            realm.add(remote, update: .modified)
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
            let allTasks = realm.objects(TaskItem.self)
            let detachedTasks = allTasks.map { $0.detached() }
            let count = detachedTasks.count
            self.repository.uploadTasks(Array(detachedTasks)) {
                completion(count)
            }
        }
    }

}

