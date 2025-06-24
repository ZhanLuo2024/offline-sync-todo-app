//
//  MainViewModel.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift
import Combine

class MainViewModel: ObservableObject {
    private let repository = TaskRepository()

    @Published var tasks: [TaskItem] = []
    @Published var syncMode: SyncMode = .full
    @Published var isSyncing = false
    @Published var syncReportText = ""
    @Published var showReport = false
    @Published var conflictStrategy = "LWW"
    @Published var reloadToken = UUID()
    @Published var isEditing = false

    init() {
        loadTasks()
    }

    func loadTasks() {
        let results = repository.fetchTasks()
        self.tasks = Array(results)
    }

    func currentStrategy() -> SyncStrategy {
        switch syncMode {
        case .full:
            return FullSyncStrategy()
        case .delta:
            return DeltaSyncStrategy()
        }
    }

    func performSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let strategy = currentStrategy()
        let prepared = strategy.prepareTasks(for: tasks)
        let syncModeStr = syncMode == .full ? "full" : "delta"

        let mappedTasks = prepared.map { task -> [String: Any] in
            var t: [String: Any] = [
                "title": task.title,
                "isCompleted": task.isCompleted
            ]
            
            
            if conflictStrategy == "LWW" {
                t["lastModified"] = task.lastModified.timeIntervalSince1970
            } else if conflictStrategy == "VV" {
                t["versionVector"] = [
                    "deviceA": 3,
                    "deviceB": 5
                ]
            }

            return t
        }

        let payload: [String: Any] = [
            "mode": syncModeStr,
            "strategy": conflictStrategy,
            "tasks": mappedTasks
        ]


        guard let url = URL(string: "https://1gnwt3y456.execute-api.eu-west-1.amazonaws.com/prods/sync"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Invalid URL or JSON encoding")
            self.isSyncing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let startTime = Date()

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSyncing = false

                if let error = error {
                    self.syncReportText = "Sync failed: \(error.localizedDescription)"
                    self.showReport = true
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.syncReportText = "Invalid response"
                    self.showReport = true
                    return
                }

                let duration = Date().timeIntervalSince(startTime)
                let itemsReceived = json["itemsReceived"] as? Int ?? 0
                let timeUsed = String(format: "%.2f", duration)

                self.syncReportText = """
                Sync successful
                Items Sent: \(prepared.count)
                Items Received: \(itemsReceived)
                Time: \(timeUsed) sec
                Mode: \(syncModeStr.capitalized)
                Strategy: \(self.conflictStrategy)
                """
                self.showReport = true

                self.loadTasks()
            }
        }.resume()
    }
    
    func generateTasks(count: Int) {
        self.tasks = []
        self.reloadToken = UUID()
        repository.clearAllTasks()
        repository.generateDummyTasks(count: count)
        loadTasks()
    }

    func randomModify(count: Int) {
        repository.randomlyModifyTasks(count: count)
        loadTasks()
    }
    
    func fetchTasks() {
        self.tasks = repository.fetchTasks()
            .sorted(byKeyPath: "lastModified", ascending: false)
            .map { $0 } 
    }


}



