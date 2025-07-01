//
//  ConflictCenter.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 01/07/2025.
//


import Foundation
import Combine
import RealmSwift

struct ConflictPair: Identifiable, Equatable {
    var id: ObjectId { local.id }
    let local: TaskItem
    let remote: TaskItem

    static func == (lhs: ConflictPair, rhs: ConflictPair) -> Bool {
        return lhs.local.id == rhs.local.id && lhs.remote.id == rhs.remote.id
    }
}

class ConflictCenter: ObservableObject {
    static let shared = ConflictCenter()

    @Published var conflicts: [ConflictPair] = []

    func addConflict(local: TaskItem, remote: TaskItem) {
            let pair = ConflictPair(local: local, remote: remote)
            conflicts.append(pair)
        }

    func removeConflict(_ pair: ConflictPair) {
        if let index = conflicts.firstIndex(of: pair) {
            conflicts.remove(at: index)
        }
    }

    func clear() {
        conflicts.removeAll()
    }

    func count() -> Int {
        return conflicts.count
    }

    func hasConflicts() -> Bool {
        return !conflicts.isEmpty
    }
    
    func resolve(pair: ConflictPair, useRemote: Bool) {
            let winner = useRemote ? pair.remote : pair.local

            do {
                let realm = try Realm()
                try realm.write {
                    if let target = realm.object(ofType: TaskItem.self, forPrimaryKey: pair.local.id) {
                        target.title = winner.title
                        target.content = winner.content
                        target.isPendingUpload = true
                        target.lastModified = Date()
                    }
                }
            } catch {
                print("⚠️ Conflict resolution failed: \(error)")
            }

            // remove from conflict list
            if let index = conflicts.firstIndex(of: pair) {
                conflicts.remove(at: index)
            }
        }
}

