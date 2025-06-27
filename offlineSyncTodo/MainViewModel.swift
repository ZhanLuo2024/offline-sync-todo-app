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
    
    @Published var lastSyncTime: Date = {
        if let saved = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date {
            return saved
        } else {
            return Date(timeIntervalSince1970: 0)
        }
    }()

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
            return FullSyncStrategy(
                repository: repository,
                deviceId: DeviceManager.shared.id,
                conflictStrategy: conflictStrategy
            )
        case .delta:
            return DeltaSyncStrategy(
                repository: repository,
                deviceId: DeviceManager.shared.id,
                conflictStrategy: conflictStrategy,
                lastSyncTime: lastSyncTime
            )
        }
    }

    func performSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let strategy = currentStrategy()

        strategy.sync { report in
            DispatchQueue.main.async {
                self.isSyncing = false
                self.lastSyncTime = Date()
                UserDefaults.standard.set(self.lastSyncTime, forKey: "lastSyncTime")

                self.syncReportText = SyncLogger.formatReport(
                    mode: self.syncMode,
                    strategy: self.conflictStrategy,
                    report: report
                )
                self.showReport = true
            }
        }
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
    }

}



