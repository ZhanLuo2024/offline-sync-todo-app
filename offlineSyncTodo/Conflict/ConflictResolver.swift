//
//  ConflictResolver.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 25/06/2025.
//


import Foundation

enum VVCompareResult {
    case localNewer
    case remoteNewer
    case concurrent  
}

struct ConflictResolver {
    
    static func compareVV(local: [String: Int], remote: [String: Int]) -> VVCompareResult {
        var localGreater = false
        var remoteGreater = false
        
        let allKeys = Set(local.keys).union(remote.keys)
        
        for key in allKeys {
            let l = local[key] ?? 0
            let r = remote[key] ?? 0
            
            if l > r {
                localGreater = true
            } else if r > l {
                remoteGreater = true
            }
        }
        
        if localGreater && !remoteGreater {
            return .localNewer
        } else if remoteGreater && !localGreater {
            return .remoteNewer
        } else {
            return .concurrent
        }
    }
    
    static func resolve(local: TaskItem, remote: TaskItem, deviceId: String) -> TaskItem {
        let merged = local

        // title 比較
        if local.title != remote.title {
            let localTitleVV = Dictionary(uniqueKeysWithValues: local.titleVersion.map { ($0.key, $0.value) })
            let remoteTitleVV = Dictionary(uniqueKeysWithValues: remote.titleVersion.map { ($0.key, $0.value) })

            let titleCompare = compareVV(local: localTitleVV, remote: remoteTitleVV)

            switch titleCompare {
            case .remoteNewer:
                merged.title = remote.title
                merged.titleVersion.removeAll()
                for key in remote.titleVersion.keys {
                    merged.titleVersion[key] = remote.titleVersion[key]
                }
            case .concurrent:
                // 暫不處理衝突
                break
            default:
                break
            }
        }

        // content 比較
        if local.content != remote.content {
            let localContentVV = Dictionary(uniqueKeysWithValues: local.contentVersion.map { ($0.key, $0.value) })
            let remoteContentVV = Dictionary(uniqueKeysWithValues: remote.contentVersion.map { ($0.key, $0.value) })

            let contentCompare = compareVV(local: localContentVV, remote: remoteContentVV)

            switch contentCompare {
            case .remoteNewer:
                merged.content = remote.content
                merged.contentVersion.removeAll()
                for key in remote.contentVersion.keys {
                    merged.contentVersion[key] = remote.contentVersion[key]
                }
            case .concurrent:
                break
            default:
                break
            }
        }


        return merged
    }

}
