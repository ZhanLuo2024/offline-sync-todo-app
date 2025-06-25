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
        var merged = local

        // title 不同時，先看是否真的改了不同欄位
        if local.title != remote.title {
            let localTitleVV = local.getFieldVersion(for: "title")
            let remoteTitleVV = remote.getFieldVersion(for: "title")


            let titleCompare = compareVV(local: localTitleVV, remote: remoteTitleVV)

            switch titleCompare {
            case .remoteNewer:
                merged.title = remote.title
                merged.setFieldVersion(for: "title", versions: remoteTitleVV)
            case .concurrent:
                // 暫不處理衝突（C1/C3）
                break
            default:
                break
            }
        }

        // content 比較
        if local.content != remote.content {
            let localContentVV = local.getFieldVersion(for: "content")
            let remoteContentVV = remote.getFieldVersion(for: "content")

            let contentCompare = compareVV(local: localContentVV, remote: remoteContentVV)

            switch contentCompare {
            case .remoteNewer:
                merged.content = remote.content
                merged.setFieldVersion(for: "content", versions: remoteContentVV)
            case .concurrent:
                // 暫不處理衝突
                break
            default:
                break
            }
        }

        return merged
    }

}
