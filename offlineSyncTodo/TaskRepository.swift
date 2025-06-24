//
//  TaskRepository.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//

import Foundation
import RealmSwift

class TaskRepository {
    private let realm: Realm

    init() {
        let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
        Realm.Configuration.defaultConfiguration = config
        self.realm = try! Realm()
    }

    func isInitialDataLoaded() -> Bool {
        return !realm.objects(TaskItem.self).isEmpty
    }

    func generateDummyTasks(count: Int = 500) {
        guard !isInitialDataLoaded() else { return }

        let tasks = (1...count).map { i -> TaskItem in
            let item = TaskItem()
            item.id = ObjectId.generate()
            item.title = "Task \(i)"
            item.content = "Content for task \(i)"
            item.isCompleted = Bool.random()
            item.lastModified = Date()
            return item
        }

        try! realm.write {
            realm.add(tasks, update: .all)
        }
    }


    func fetchTasks() -> Results<TaskItem> {
        let results = realm.objects(TaskItem.self)
        if results.isEmpty {
            generateDummyTasks()
        }
        return realm.objects(TaskItem.self).sorted(byKeyPath: "lastModified", ascending: false)
    }
    
    func clearAllTasks() {
        try! realm.write {
            let all = realm.objects(TaskItem.self)
            realm.delete(all)
        }
        print("Cleared all tasks.")
    }

    func randomlyModifyTasks(count: Int) {
        let all = realm.objects(TaskItem.self)
        guard !all.isEmpty else { return }

        let shuffled = Array(all.shuffled().prefix(min(count, all.count)))
        try! realm.write {
            for item in shuffled {
                item.title += " *"
                item.lastModified = Date()
                item.isCompleted.toggle()
            }
        }
        print("Modified \(shuffled.count) tasks randomly.")
    }

}


