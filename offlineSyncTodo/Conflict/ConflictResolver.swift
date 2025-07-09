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

struct ConflictResolver {
    
    static func compareVV(local: [String: Int], remote: [String: Int]) -> VVCompareResult {
        var localDominates = true
        var remoteDominates = true
        var anyLocalGreater = false
        var anyRemoteGreater = false

        let allKeys = Set(local.keys).union(remote.keys)

        for key in allKeys {
            let l = local[key] ?? 0
            let r = remote[key] ?? 0

            if l < r {
                localDominates = false
                anyRemoteGreater = true
            } else if l > r {
                remoteDominates = false
                anyLocalGreater = true
            }
        }

        if localDominates && anyLocalGreater {
            return .localNewer
        } else if remoteDominates && anyRemoteGreater {
            return .remoteNewer
        } else {
            return .concurrent
        }
    }
    
    static func resolve(local: TaskItem, remote: TaskItem, deviceId: String) -> TaskItem {
        let merged = TaskItem()
        merged.id = local.id

        // 先拷貝本地
        merged.title = local.title
        merged.content = local.content
        merged.titleVersion = local.titleVersion
        merged.contentVersion = local.contentVersion

        // title
        if local.title != remote.title {
            let localTitleVV = toDictionary(local.titleVersion)
            let remoteTitleVV = toDictionary(remote.titleVersion)

            let titleCompare = compareVV(local: localTitleVV, remote: remoteTitleVV)

            switch titleCompare {
            case .remoteNewer:
                merged.title = remote.title
                merged.titleVersion.removeAll()
                for entry in remote.titleVersion {
                    merged.titleVersion[entry.key] = entry.value
                }
            case .concurrent:
                // 暫不處理衝突
                break
            default:
                break
            }
        }

        // content
        if local.content != remote.content {
            let localContentVV = toDictionary(local.contentVersion)
            let remoteContentVV = toDictionary(remote.contentVersion)

            let contentCompare = compareVV(local: localContentVV, remote: remoteContentVV)

            switch contentCompare {
            case .remoteNewer:
                merged.content = remote.content
                merged.contentVersion.removeAll()
                for entry in remote.contentVersion {
                    merged.titleVersion[entry.key] = entry.value
                }
            case .concurrent:
                break
            default:
                break
            }
        }

        return merged
    }

    static func toDictionary(_ map: Map<String, Int>) -> [String: Int] {
        return Dictionary(uniqueKeysWithValues: map.map { ($0.key, $0.value) })
    }

}

extension ConflictResolver {
    static func resolve(pair: ConflictPair, useRemote: Bool) {
        let winner = useRemote ? pair.remote.detached() : pair.local.detached()

        DispatchQueue.global().async {
            do {
                let realm = try Realm()
                try realm.write {
                    if let target = realm.object(ofType: TaskItem.self, forPrimaryKey: pair.local.id) {
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

                DispatchQueue.main.async {
                    // 移除已解決的衝突
                    ConflictCenter.shared.removeConflict(pair)

                    // 自動上傳
                    uploadResolvedTask(winner)
                }

            } catch {
                print("Conflict resolution failed: \(error)")
            }
        }
    }

    private static func uploadResolvedTask(_ task: TaskItem) {
        let repository = TaskRepository()
        repository.uploadTasks([task]) { payloadSize in
            print("Resolved task uploaded. Payload size: \(payloadSize) bytes.")
        }
    }
}


