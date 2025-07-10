//
//  MainViewModel.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//

import Foundation
import RealmSwift
import Combine

/// 每次同步的記錄
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

/// 測試用例類型
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

    /// 加載本地任務
    func loadTasks() {
        let results = repository.fetchTasks()
        self.tasks = Array(results)
    }

    /// 獲取當前同步策略
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

    /// 執行同步
    func performSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let strategy = currentStrategy()

        strategy.sync { report in
            DispatchQueue.main.async {
                self.isSyncing = false

                if ConflictCenter.shared.hasPendingConflicts {
                    // 檢測到衝突，不顯示 report，直接跳轉
                    NotificationCenter.default.post(name: .didDetectConflicts, object: nil)
                    return
                }
                
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
            }
        }
    }

    /// 當衝突全部解決後重置狀態
    func onConflictResolved() {
        DispatchQueue.main.async {
            self.isSyncing = false
            self.fetchTasks()
        }
    }

    /// 生成測試任務
    func generateTasks(count: Int) {
        self.tasks = []
        self.reloadToken = UUID()
        repository.clearAllTasks()
        repository.generateDummyTasks(count: count)
        loadTasks()
    }

    /// 重新獲取本地任務
    func fetchTasks() {
        DispatchQueue.main.async {
            let realm = try! Realm()
            let objects = realm.objects(TaskItem.self)
            self.tasks = objects.map { $0.detached() }
            self.reloadToken = UUID()
        }
    }


}

/// 衝突通知
extension Notification.Name {
    static let didDetectConflicts = Notification.Name("didDetectConflicts")
    static let didUpdateFromRemote = Notification.Name("didUpdateFromRemote")
}
