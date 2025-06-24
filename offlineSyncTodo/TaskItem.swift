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

}


