//
//  DeltaSyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift

class DeltaSyncStrategy: SyncStrategy {
    var strategyName: String {
        return "Delta Sync"
    }

    func prepareTasks(for tasks: [TaskItem]) -> [TaskItem] {
        let realm = try! Realm()

        // Randomly select 5 pens for simulation
        let count = min(5, tasks.count)
        let randomTasks = Array(tasks.shuffled().prefix(count))

        try! realm.write {
            for task in randomTasks {
                task.title += " *"
                task.isCompleted.toggle()
                task.lastModified = Date()
            }
        }

        return randomTasks
    }
}
