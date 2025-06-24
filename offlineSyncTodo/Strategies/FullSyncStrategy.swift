//
//  FullSyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift

class FullSyncStrategy: SyncStrategy {
    var strategyName: String {
        return "Full Sync"
    }

    func prepareTasks(for tasks: [TaskItem]) -> [TaskItem] {
        return Array(tasks) 
    }
}
