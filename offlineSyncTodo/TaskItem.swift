//
//  TaskItem.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//


import Foundation
import RealmSwift

class TaskItem: Object, Identifiable {
    @Persisted(primaryKey: true) var id: ObjectId = ObjectId.generate()
    @Persisted var title: String = ""
    @Persisted var content: String = ""
    @Persisted var isCompleted: Bool = false
    @Persisted var lastModified: Date = Date()
    @Persisted var isTitleModified: Bool = false
    @Persisted var isContentModified: Bool = false
    @Persisted var versionVector: Map<String, FieldVersion>

}


class FieldVersion: EmbeddedObject {
    @Persisted var versions: Map<String, Int>
}


extension TaskItem {
    func setFieldVersion(for key: String, versions: [String: Int]) {
        let field = FieldVersion()
        for (k, v) in versions {
            field.versions[k] = v
        }
        versionVector[key] = field
    }

    func getFieldVersion(for key: String) -> [String: Int] {
        return versionVector[key]?.versions.reduce(into: [:]) { $0[$1.key] = $1.value } ?? [:]
    }
}
