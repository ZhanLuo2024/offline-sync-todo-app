//
//  EditTaskView.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 24/06/2025.
//


import SwiftUI
import RealmSwift

struct EditTaskView: View {
    @Binding var task: TaskItem?
    @ObservedObject var viewModel: MainViewModel
    let conflictStrategy: String

    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""

    var body: some View {
        NavigationView {
            if let task = task {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Title", text: $editedTitle)
                    }

                    Section(header: Text("Content")) {
                        TextField("Content", text: $editedContent)
                    }

                    Section {
                        Button("Save") {
                            saveChanges(for: task.id)
                        }
                    }
                }
                .navigationTitle("Edit Task")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    editedTitle = task.title
                    editedContent = task.content
                }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    func saveChanges(for taskId: String) {
        let realm = try! Realm()
        let deviceId = DeviceManager.shared.id

        try! realm.write {
            guard let realmTask = realm.object(ofType: TaskItem.self, forPrimaryKey: taskId) else {
                print("Could not find TaskItem with id \(taskId)")
                return
            }

            var didModify = false

            if realmTask.title != editedTitle {
                realmTask.title = editedTitle
                realmTask.isTitleModified = true
                didModify = true

                if conflictStrategy == "VV" {
                    let current = realmTask.titleVersion[deviceId] ?? 0
                    realmTask.titleVersion[deviceId] = current + 1
                }
            }

            if realmTask.content != editedContent {
                realmTask.content = editedContent
                realmTask.isContentModified = true
                didModify = true

                if conflictStrategy == "VV" {
                    let current = realmTask.contentVersion[deviceId] ?? 0
                    realmTask.contentVersion[deviceId] = current + 1
                }
            }

            if didModify {
                realmTask.lastModified = Date()
                realmTask.isPendingUpload = true
            }

            print("🔷 Task after save:")
            print("- id: \(realmTask.id)")
            print("- title: \(realmTask.title)")
            print("- content: \(realmTask.content)")
            print("- titleVersion: \(realmTask.titleVersion)")
            print("- contentVersion: \(realmTask.contentVersion)")
        }

        viewModel.fetchTasks()
        self.task = nil
    }
}




