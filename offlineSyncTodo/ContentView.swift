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

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTask: TaskItem? = nil
    @State private var navigateToConflictResolution = false

    var body: some View {
        NavigationStack {
            VStack {
                SyncModePicker(viewModel: viewModel)

                ConflictStrategyPicker(viewModel: viewModel)

                TaskControlButtons(viewModel: viewModel)

                TaskList(viewModel: viewModel, selectedTask: $selectedTask)

                SyncHint(syncMode: viewModel.syncMode)

                SyncButton(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $navigateToConflictResolution) {
                ConflictResolutionView()
            }
            .alert("Sync Report", isPresented: $viewModel.showReport) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.syncReportText)
            }
            .sheet(item: $selectedTask) { task in
                EditTaskView(task: $selectedTask, conflictStrategy: viewModel.conflictStrategy)
            }
            .onAppear {
                viewModel.fetchTasks()
                NotificationCenter.default.removeObserver(self, name: Notification.Name("TaskUpdated"), object: nil)
                NotificationCenter.default.addObserver(forName: Notification.Name("TaskUpdated"), object: nil, queue: .main) { _ in
                    viewModel.fetchTasks()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didDetectConflicts)) { _ in
                navigateToConflictResolution = true
            }
            .navigationTitle("Offline Tasks")
        }
    }
}

// MARK: - subviews
struct SyncModePicker: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        Picker("Sync Mode", selection: $viewModel.syncMode) {
            ForEach(SyncMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
}

struct ConflictStrategyPicker: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack {
            Text("Conflict Resolution Strategy")
                .font(.subheadline)
                .padding(.top, 4)

            Picker("Strategy", selection: $viewModel.conflictStrategy) {
                Text("Last Write Wins").tag("LWW")
                Text("Version Vector").tag("VV")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
    }
}

struct TaskControlButtons: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack {
            HStack {
                Text("Generate Tasks:")
                ForEach([10, 100, 500, 1000], id: \.self) { count in
                    Button("\(count)") {
                        viewModel.generateTasks(count: count)
                    }
                    .padding(4)
                }
            }
        }
    }
}

struct TaskList: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedTask: TaskItem?

    var body: some View {
        List {
            ForEach(viewModel.tasks, id: \.id) { task in
                TaskRow(task: task, conflictStrategy: viewModel.conflictStrategy)
                    .onTapGesture {
                        if viewModel.conflictStrategy == "VV" {
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






