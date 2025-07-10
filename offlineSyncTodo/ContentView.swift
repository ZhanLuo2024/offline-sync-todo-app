//
//  ContentView.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//

import SwiftUI
import RealmSwift

enum SyncMode: String, CaseIterable, Identifiable {
    case full = "Full Sync"
    case delta = "Delta Sync"
    var id: String { self.rawValue }
}

enum TestCase: String, CaseIterable, Identifiable {
    case rq1 = "RQ1"
    case rq2 = "RQ2"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @ObservedObject private var conflictCenter = ConflictCenter.shared
    @State private var selectedTask: TaskItem? = nil
    @State private var showConflictResolution = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Test case selector
                Picker("Test Case", selection: $viewModel.testCaseType) {
                    ForEach(TestCaseType.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                Picker("Sync Mode", selection: $viewModel.syncMode) {
                    ForEach(SyncMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                Picker("Strategy", selection: $viewModel.conflictStrategy) {
                    Text("Last Write Wins").tag("LWW")
                    Text("Version Vector").tag("VV")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                TaskControlButtons(viewModel: viewModel)

                TaskList(viewModel: viewModel, selectedTask: $selectedTask)

                SyncHint(syncMode: viewModel.syncMode)

                SyncButton(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showConflictResolution) {
                ConflictResolutionView(viewModel: viewModel)
            }
            .alert("Sync Report", isPresented: $viewModel.showReport) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.syncReportText)
            }
            .sheet(item: $selectedTask) { task in
                EditTaskView(
                    task: $selectedTask,
                    viewModel: viewModel,
                    conflictStrategy: viewModel.conflictStrategy
                )
            }
            .onAppear {
                viewModel.fetchTasks()
            }
            .onChange(of: conflictCenter.conflicts) {
                showConflictResolution = conflictCenter.hasPendingConflicts
            }
            .onReceive(NotificationCenter.default.publisher(for: .didDetectConflicts)) { _ in
                self.showConflictResolution = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .didUpdateFromRemote)) { _ in
                viewModel.fetchTasks()
            }
        }
    }
}

struct TaskControlButtons: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Generate Tasks:")
                ForEach([10, 100, 500, 1000], id: \ .self) { count in
                    Button("\(count)") {
                        viewModel.generateTasks(count: count)
                    }.padding(4)
                }
            }

            HStack {
                Text("Select Device:")
                Button("Device A") {
                    DeviceManager.shared.setDeviceId("devA12")
                    viewModel.currentDevice = "devA12"
                }.padding(4)
                Button("Device B") {
                    DeviceManager.shared.setDeviceId("devB34")
                    viewModel.currentDevice = "devB34"
                }.padding(4)
            }
        }
    }
}

struct TaskList: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedTask: TaskItem?

    var body: some View {
        List {
            ForEach(viewModel.tasks, id: \ .id) { task in
                TaskRow(task: task, conflictStrategy: viewModel.conflictStrategy)
                    .onTapGesture {
                        if viewModel.testCaseType == .rq2 {
                            selectedTask = task
                        }
                    }
            }
        }
        .id(viewModel.reloadToken)
    }
}

struct TaskRow: View {
    let task: TaskItem
    let conflictStrategy: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("📝 \(task.title)").font(.headline)
                if conflictStrategy == "VV", task.isTitleModified {
                    Text("T").bold().foregroundColor(.red).font(.caption).padding(.leading, 4)
                }
            }

            HStack {
                Text("📄 \(task.content)").font(.subheadline).foregroundColor(.gray)
                if conflictStrategy == "VV", task.isContentModified {
                    Text("C").bold().foregroundColor(.blue).font(.caption).padding(.leading, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SyncHint: View {
    let syncMode: SyncMode

    var body: some View {
        Text(syncMode == .full ?
             "Full Sync: All local tasks will be uploaded every time." :
             "Delta Sync: Only a subset of modified tasks will be uploaded.")
        .font(.footnote)
        .foregroundColor(.gray)
        .padding(.horizontal)
    }
}

struct SyncButton: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        Button(action: {
            viewModel.performSync()
        }) {
            Text(viewModel.isSyncing ? "Syncing..." : "Sync")
                .frame(maxWidth: .infinity)
        }
        .padding()
        .disabled(viewModel.isSyncing)
        .buttonStyle(.borderedProminent)
    }
}







