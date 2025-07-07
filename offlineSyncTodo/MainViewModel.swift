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

enum TestCaseType: String, CaseIterable, Identifiable {
    case rq1 = "RQ1"
    case rq2 = "RQ2"
    var id: String { self.rawValue }
}

class MainViewModel: ObservableObject {
    private let repository = TaskRepository()

    @Published var tasks: [TaskItem] = []
    @Published var syncMode: SyncMode = .full
    @Published var isSyncing = false
    @Published var syncReportText = ""
    @Published var showReport = false
    @Published var conflictStrategy = "LWW" {
        didSet {
            UserDefaults.standard.set(conflictStrategy, forKey: "conflictStrategy")
        }
    }
    @Published var reloadToken = UUID()
    @Published var isEditing = false
    @Published var syncLogs: [SyncLog] = []
    @Published var currentDevice: String = DeviceManager.shared.id
    @Published var testCaseType: TestCaseType = .rq1
    
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
                lastSyncTime: lastSyncTime,
                testCaseType: testCaseType
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
                if report.itemsSent > 0 || report.itemsReceived > 0 {
                    self.lastSyncTime = Date()
                    UserDefaults.standard.set(self.lastSyncTime, forKey: "lastSyncTime")
                }

                self.syncReportText = SyncLogger.formatReport(
                    mode: self.syncMode,
                    strategy: self.conflictStrategy,
                    report: report
                )
                self.showReport = true
                
                if !ConflictCenter.shared.conflicts.isEmpty {
                    NotificationCenter.default.post(name: .didDetectConflicts, object: nil)
                }
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
    
    func fetchTasks() {
        self.tasks = Array(repository.fetchTasks())
    }
}

extension Notification.Name {
    static let didDetectConflicts = Notification.Name("didDetectConflicts")
}
