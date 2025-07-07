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
                            saveChanges(for: task)
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

    func saveChanges(for task: TaskItem) {
        let realm = try! Realm()

        try! realm.write {
            var didModify = false

            if task.title != editedTitle {
                task.title = editedTitle
                task.isTitleModified = true
                didModify = true

                if conflictStrategy == "VV" {
                    let deviceId = DeviceManager.shared.id
                    let current = task.titleVersion[deviceId] ?? 0
                    task.titleVersion[deviceId] = current + 1
                }
            }

            if task.content != editedContent {
                task.content = editedContent
                task.isContentModified = true
                didModify = true

                if conflictStrategy == "VV" {
                    let deviceId = DeviceManager.shared.id
                    let current = task.contentVersion[deviceId] ?? 0
                    task.contentVersion[deviceId] = current + 1
                }
            }

            if didModify {
                task.lastModified = Date()
            }
        }

        viewModel.fetchTasks()
        self.task = nil          
    }
}


