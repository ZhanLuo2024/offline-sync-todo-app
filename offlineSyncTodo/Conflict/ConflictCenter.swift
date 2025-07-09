//
//  ConflictCenter.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 01/07/2025.
//

import Foundation
import Combine
import RealmSwift

/// 一對衝突的本地/遠端版本
struct ConflictPair: Identifiable, Equatable {
    var id: String { local.id }
    let local: TaskItem
    let remote: TaskItem

    static func == (lhs: ConflictPair, rhs: ConflictPair) -> Bool {
        lhs.local.id == rhs.local.id && lhs.remote.id == rhs.remote.id
    }
}

/// 管理衝突的中心
class ConflictCenter: ObservableObject {
    static let shared = ConflictCenter()

    /// 當前衝突列表
    @Published private(set) var conflicts: [ConflictPair] = [] {
        didSet {
            self.hasPendingConflicts = !self.conflicts.isEmpty
        }
    }

    /// 是否有未解決的衝突
    @Published private(set) var hasPendingConflicts: Bool = false

    /// 添加一個衝突
    func addConflict(local: TaskItem, remote: TaskItem) {
        // 複製一份脫離 Realm 的對象
        let pair = ConflictPair(local: local.detached(), remote: remote.detached())
        DispatchQueue.main.async {
            self.conflicts.append(pair)
        }
    }

    /// 移除一個衝突
    func removeConflict(_ pair: ConflictPair) {
        DispatchQueue.main.async {
            self.conflicts.removeAll { $0 == pair }
        }
    }

    /// 清空所有衝突
    func clear() {
        DispatchQueue.main.async {
            self.conflicts.removeAll()
        }
    }

    /// 當前衝突數量
    var count: Int {
        conflicts.count
    }

    /// 解決一個衝突並選擇保留的版本
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
            print("Conflict resolution failed: \(error)")
        }

        removeConflict(pair)
    }
}
