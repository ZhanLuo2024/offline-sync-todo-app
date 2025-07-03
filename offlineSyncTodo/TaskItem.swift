//
//  TaskItem.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//


import Foundation
import RealmSwift

class TaskItem: Object, Identifiable, Codable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var title: String = ""
    @Persisted var content: String = ""
    @Persisted var isCompleted: Bool = false
    @Persisted var lastModified: Date = Date()
    @Persisted var isTitleModified: Bool = false
    @Persisted var isContentModified: Bool = false
    @Persisted var isPendingUpload: Bool = false
    @Persisted var titleVersion: Map<String, Int>
    @Persisted var contentVersion: Map<String, Int>

    enum CodingKeys: String, CodingKey {
        case id, title, content, isCompleted, lastModified,
             isTitleModified, isContentModified,
             titleVersion, contentVersion
    }

    required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.lastModified = try container.decode(Date.self, forKey: .lastModified)
        self.isTitleModified = try container.decode(Bool.self, forKey: .isTitleModified)
        self.isContentModified = try container.decode(Bool.self, forKey: .isContentModified)

        let titleVersionDict = try container.decode([String: Int].self, forKey: .titleVersion)
        for (k, v) in titleVersionDict {
            self.titleVersion[k] = v
        }

        let contentVersionDict = try container.decode([String: Int].self, forKey: .contentVersion)
        for (k, v) in contentVersionDict {
            self.contentVersion[k] = v
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(isTitleModified, forKey: .isTitleModified)
        try container.encode(isContentModified, forKey: .isContentModified)

        var titleVersionDict: [String: Int] = [:]
        for entry in titleVersion {
            titleVersionDict[entry.key] = entry.value
        }
        try container.encode(titleVersionDict, forKey: .titleVersion)

        var contentVersionDict: [String: Int] = [:]
        for entry in contentVersion {
            contentVersionDict[entry.key] = entry.value
        }
        try container.encode(contentVersionDict, forKey: .contentVersion)
    }
}

extension TaskItem {
    func detached() -> TaskItem {
        let clone = TaskItem()
        clone.id = self.id
        clone.title = self.title
        clone.content = self.content
        clone.isCompleted = self.isCompleted
        clone.lastModified = self.lastModified
        clone.isTitleModified = self.isTitleModified
        clone.isContentModified = self.isContentModified

        for entry in self.titleVersion {
            clone.titleVersion[entry.key] = entry.value
        }

        for entry in self.contentVersion {
            clone.contentVersion[entry.key] = entry.value
        }

        return clone
    }
}


