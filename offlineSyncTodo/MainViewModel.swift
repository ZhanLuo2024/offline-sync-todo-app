//
//  MainViewModel.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift
import Combine

struct SyncLog: Identifiable {
    let id = UUID()
    let success: Bool
    let sent: Int
    let received: Int
    let timeUsed: Double
    let mode: String
    let strategy: String
    let payloadSize: Int
    let timestamp: Date
}


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
    @Published var syncLogs: [SyncLog] = []


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
                "content": task.content,
                "isCompleted": task.isCompleted
            ]

            if conflictStrategy == "LWW" {
                t["lastModified"] = task.lastModified.timeIntervalSince1970
            } else if conflictStrategy == "VV" {
                t["versionVector"] = task.versionVector
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

        let payloadSize = jsonData.count
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSyncing = false
                let duration = Date().timeIntervalSince(startTime)

                if let error = error {
                    self.syncReportText = "Sync failed: \(error.localizedDescription)"
                    self.syncLogs.append(SyncLog(
                        success: false,
                        sent: prepared.count,
                        received: 0,
                        timeUsed: duration,
                        mode: syncModeStr.capitalized,
                        strategy: self.conflictStrategy,
                        payloadSize: payloadSize,
                        timestamp: Date()
                    ))
                    self.showReport = true
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.syncReportText = "Invalid response"
                    self.showReport = true
                    return
                }

                let itemsReceived = json["itemsReceived"] as? Int ?? 0
                let timeUsed = String(format: "%.2f", duration)

                self.syncReportText = """
                Sync successful
                Items Sent: \(prepared.count)
                Items Received: \(itemsReceived)
                Payload: \(payloadSize) bytes
                Time: \(timeUsed) sec
                Mode: \(syncModeStr.capitalized)
                Strategy: \(self.conflictStrategy)
                """

                self.syncLogs.append(SyncLog(
                    success: true,
                    sent: prepared.count,
                    received: itemsReceived,
                    timeUsed: duration,
                    mode: syncModeStr.capitalized,
                    strategy: self.conflictStrategy,
                    payloadSize: payloadSize,
                    timestamp: Date()
                ))

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



