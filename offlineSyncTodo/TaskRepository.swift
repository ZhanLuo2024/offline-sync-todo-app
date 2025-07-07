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

struct TaskListResponse: Codable {
    let tasks: [TaskItem]
}

class TaskRepository {
    
    func fetchRemoteTasks(completion: @escaping ([TaskItem]) -> Void) {
        guard let url = URL(string: "https://9uvddcutsc.execute-api.eu-west-1.amazonaws.com/prod/sync") else {
            print("Invalid URL")
            completion([])
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                print("Fetch error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            print(String(data: data, encoding: .utf8) ?? "no data")

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let decoded = try decoder.decode(TaskListResponse.self, from: data)
                completion(decoded.tasks)
            } catch {
                print("Decode error: \(error)")
                completion([])
            }
        }

        task.resume()
    }


    func uploadTasks(_ tasks: [TaskItem], completion: @escaping (Int) -> Void) {
        let syncModeStr = UserDefaults.standard.string(forKey: "syncMode") ?? "full"
        let conflictStrategy = UserDefaults.standard.string(forKey: "conflictStrategy") ?? "LWW"

        let mappedTasks: [[String: Any]] = tasks.map { task in
            var dict: [String: Any] = [
                "id": task.id,
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

            print("Uploading task:", dict)
            return dict
        }

        let payload: [String: Any] = [
            "mode": syncModeStr,
            "strategy": conflictStrategy,
            "tasks": mappedTasks
        ]

        guard let url = URL(string: "https://9uvddcutsc.execute-api.eu-west-1.amazonaws.com/prod/sync"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Invalid upload payload")
            completion(0)
            return
        }

        let payloadSize = jsonData.count
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(payloadSize)
            }
        }.resume()
    }
    
    func fetchTasks() -> [TaskItem] {
        let realm = try! Realm()
        return Array(realm.objects(TaskItem.self).sorted(byKeyPath: "lastModified", ascending: false))
    }
    
    func clearAllTasks() {
        let realm = try! Realm()
        try! realm.write {
            realm.delete(realm.objects(TaskItem.self))
        }
    }
    
    func generateDummyTasks(count: Int) {
        let realm = try! Realm()
        let tasks = (1...count).map { i -> TaskItem in
            let task = TaskItem()
            task.id = "task-\(i)"
            task.title = "Task \(i)"
            task.content = "Content \(i)"
            task.lastModified = Date()
            return task
        }

        try! realm.write {
            realm.deleteAll()
            realm.add(tasks, update: .modified) 
        }
    }

}



