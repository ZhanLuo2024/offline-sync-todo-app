//
//  SyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift

protocol SyncStrategy {
    var strategyName: String { get }
    func prepareTasks(for tasks: [TaskItem]) -> [TaskItem]
}
