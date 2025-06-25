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
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTask: TaskItem? = nil
    @State private var showEditView: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                // Sync Mode Picker
                Picker("Sync Mode", selection: $viewModel.syncMode) {
                    ForEach(SyncMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Text("Conflict Resolution Strategy")
                    .font(.subheadline)
                    .padding(.top, 4)

                Picker("Strategy", selection: $viewModel.conflictStrategy) {
                    Text("Last Write Wins").tag("LWW")
                    Text("Version Vector").tag("VV")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Task control buttons
                if viewModel.conflictStrategy == "LWW" {
                    HStack {
                        Text("Generate Tasks:")
                        ForEach([10, 100, 500, 1000], id: \.self) { count in
                            Button("\(count)") {
                                viewModel.generateTasks(count: count)
                            }
                            .padding(4)
                        }
                    }

                    HStack {
                        Text("Random Modify:")
                        ForEach([10, 100, 500], id: \.self) { count in
                            Button("\(count)") {
                                viewModel.randomModify(count: count)
                            }
                            .padding(4)
                        }
                    }
                } else {
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

                // Task List
                List {
                    ForEach(viewModel.tasks, id: \.id.stringValue) { task in
                        VStack(alignment: .leading) {
                            HStack {
                                Text("📝 \(task.title)")
                                    .font(.headline)
                                if viewModel.conflictStrategy == "VV", task.isTitleModified {
                                    Text("T")
                                        .bold()
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(.leading, 4)
                                }
                            }

                            HStack {
                                Text("📄 \(task.content)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if viewModel.conflictStrategy == "VV", task.isContentModified {
                                    Text("C")
                                        .bold()
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            if viewModel.conflictStrategy == "VV" {
                                selectedTask = task
                            }
                        }
                    }
                }
                .id(viewModel.reloadToken)

                Text(viewModel.syncMode == .full ?
                     "Full Sync: All local tasks will be uploaded every time." :
                     "Delta Sync: 5 random tasks are modified before each sync to simulate offline edits.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

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
            .onAppear {
                viewModel.fetchTasks()

                NotificationCenter.default.removeObserver(
                    self,
                    name: Notification.Name("TaskUpdated"),
                    object: nil
                )

                NotificationCenter.default.addObserver(
                    forName: Notification.Name("TaskUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    viewModel.fetchTasks()
                }
            }
            .navigationTitle("Offline Tasks")
        } // <- NavigationView ends here
        .sheet(item: $selectedTask) { task in
            EditTaskView(task: $selectedTask, conflictStrategy: viewModel.conflictStrategy)
        }
        .alert("Sync Report", isPresented: $viewModel.showReport) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.syncReportText)
        }
    }
}

