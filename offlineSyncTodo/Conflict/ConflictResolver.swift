//
//  ConflictResolver.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 25/06/2025.
//


import Foundation
import RealmSwift

enum VVCompareResult {
    case localNewer
    case remoteNewer
    case concurrent
}

class ConflictResolver {
    
    static func resolve(local: TaskItem, remote: TaskItem, deviceId: String) -> TaskItem {
        // 直接用 local 改
        let merged = local
        
        // 🔷 合併 Title
        if compareVV(local: toDictionary(local.titleVersion), remote: toDictionary(remote.titleVersion)) == .remoteNewer {
            merged.title = remote.title
            merged.titleVersion.removeAll()
            for entry in remote.titleVersion {
                merged.titleVersion[entry.key] = entry.value
            }
        }
        
        // 🔷 合併 Content
        if compareVV(local: toDictionary(local.contentVersion), remote: toDictionary(remote.contentVersion)) == .remoteNewer {
            merged.content = remote.content
            merged.contentVersion.removeAll()
            for entry in remote.contentVersion {
                merged.contentVersion[entry.key] = entry.value
            }
        }
        
        merged.isPendingUpload = true
        
        return merged
    }
    
    static func toDictionary(_ map: Map<String, Int>) -> [String: Int] {
        var dict: [String: Int] = [:]
        for entry in map {
            dict[entry.key] = entry.value
        }
        return dict
    }
    
    static func compareVV(local: [String: Int], remote: [String: Int]) -> VVCompareResult {
        var localNewer = false
        var remoteNewer = false
        
        let keys = Set(local.keys).union(remote.keys)
        for key in keys {
            let l = local[key] ?? 0
            let r = remote[key] ?? 0
            if l < r { remoteNewer = true }
            if l > r { localNewer = true }
        }
        
        if remoteNewer && !localNewer { return .remoteNewer }
        if localNewer && !remoteNewer { return .localNewer }
        return .concurrent
    }
}


extension ConflictResolver {
    static func resolveAndUpload(pair: ConflictPair, useRemote: Bool, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            do {
                let realm = try Realm()
                let deviceId = DeviceManager.shared.id

                try realm.write {
                    if let target = realm.object(ofType: TaskItem.self, forPrimaryKey: pair.local.id) {
                        let winner = useRemote ? pair.remote : pair.local

                        target.title = winner.title
                        target.content = winner.content
                        target.isPendingUpload = true
                        target.lastModified = Date()

                        target.titleVersion.removeAll()
                        for entry in winner.titleVersion {
                            target.titleVersion[entry.key] = entry.value
                        }
                        target.contentVersion.removeAll()
                        for entry in winner.contentVersion {
                            target.contentVersion[entry.key] = entry.value
                        }
                    }
                }

                print("🔥 conflicts: \(ConflictCenter.shared.conflicts.count)")
                
                DispatchQueue.main.async {
                    ConflictCenter.shared.removeConflict(pair)

                    if ConflictCenter.shared.conflicts.isEmpty {
                        uploadResolvedTask(pair.local.id) {
                            // 🔷 上傳後強制刷新本地
                            fetchAndUpdateLocal(taskId: pair.local.id, completion: completion)
                        }
                    } else {
                        completion()
                    }
                }

            } catch {
                print("Conflict resolution failed: \(error)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private static func uploadResolvedTask(_ taskId: String, completion: @escaping () -> Void) {
        let realm = try! Realm()
        if let task = realm.object(ofType: TaskItem.self, forPrimaryKey: taskId) {
            let repository = TaskRepository()
            repository.uploadTasks([task]) { payloadSize in
                print("Resolved task uploaded. Payload size: \(payloadSize) bytes.")
                completion()
            }
        } else {
            completion()
        }
    }

    /// 拉取遠端最新，更新本地
    private static func fetchAndUpdateLocal(taskId: String, completion: @escaping () -> Void) {
        let repository = TaskRepository()
        repository.fetchRemoteTasks { remoteTasks in
            if let remoteTask = remoteTasks.first(where: { $0.id == taskId }) {
                DispatchQueue.main.async {
                    let realm = try! Realm()
                    try! realm.write {
                        realm.add(remoteTask, update: .modified)
                    }
                    print("本地刷新完成 (task: \(taskId))")
                    completion()
                }
            } else {
                print("遠端沒有找到 task \(taskId)，本地未更新")
                completion()
            }
        }
    }
}




