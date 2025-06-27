//
//  TaskRepository.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//

// TaskRepository.swift
// offlineSyncTodo

import Foundation
import RealmSwift

class TaskRepository {
    
    func fetchRemoteTasks(completion: @escaping ([TaskItem]) -> Void) {
        guard let url = URL(string: "https://1gnwt3y456.execute-api.eu-west-1.amazonaws.com/prods/sync") else {
            print("Invalid URL")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                print("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                struct TaskResponse: Decodable {
                    let tasks: [TaskItem]
                }

                let response = try decoder.decode(TaskResponse.self, from: data)
                let remoteTasks = response.tasks
                print("📥 Remote tasks received: \(remoteTasks.count)")
                completion(remoteTasks)

            } catch {
                print("Decode error: \(error)")
                print("Raw data: \(String(data: data, encoding: .utf8) ?? "Unreadable")")
                completion([])
            }
        }.resume()
    }


    func uploadTasks(_ tasks: [TaskItem], completion: @escaping () -> Void) {
        let syncModeStr = UserDefaults.standard.string(forKey: "syncMode") ?? "full"
        let conflictStrategy = UserDefaults.standard.string(forKey: "conflictStrategy") ?? "LWW"

        let mappedTasks: [[String: Any]] = tasks.map { task in
            var dict: [String: Any] = [
                "title": task.title,
                "content": task.content,
                "isCompleted": task.isCompleted
            ]

            if conflictStrategy == "LWW" {
                dict["lastModified"] = task.lastModified.timeIntervalSince1970
            } else if conflictStrategy == "VV" {
                dict["versionVector"] = [
                    "titleVersion": Dictionary(uniqueKeysWithValues: task.titleVersion.map { ($0.key, $0.value) }),
                    "contentVersion": Dictionary(uniqueKeysWithValues: task.contentVersion.map { ($0.key, $0.value) })
                ]
            }

            return dict
        }

        let payload: [String: Any] = [
            "mode": syncModeStr,
            "strategy": conflictStrategy,
            "tasks": mappedTasks
        ]

        guard let url = URL(string: "https://1gnwt3y456.execute-api.eu-west-1.amazonaws.com/prods/sync"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Invalid upload payload")
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
            }
            completion()
        }.resume()
    }
    
    func fetchTasks() -> [TaskItem] {
        let realm = try! Realm()
        let results = realm.objects(TaskItem.self)
            .sorted(byKeyPath: "lastModified", ascending: false)
        return results.map { $0.detached() }
    }
    
    func clearAllTasks() {
        let realm = try! Realm()
        let allTasks = realm.objects(TaskItem.self)
        try! realm.write {
            realm.delete(allTasks)
        }
    }
    
    func generateDummyTasks(count: Int) {
        let realm = try! Realm()
        try! realm.write {
            for i in 0..<count {
                let task = TaskItem()
                task.title = "Task \(i)"
                task.content = "Content \(i)"
                task.lastModified = Date()
                realm.add(task)
            }
        }
    }
    
    func randomlyModifyTasks(count: Int) {
        let realm = try! Realm()
        let tasks = realm.objects(TaskItem.self)
        guard tasks.count > 0 else { return }

        try! realm.write {
            for _ in 0..<count {
                if let randomTask = tasks.randomElement() {
                    randomTask.title += " (modified)"
                    randomTask.lastModified = Date()
                }
            }
        }
    }
}



