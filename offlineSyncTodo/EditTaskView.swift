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
    let conflictStrategy: String
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""

    var body: some View {
        NavigationView {
            if task != nil {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Title", text: $editedTitle)
                    }

                    Section(header: Text("Content")) {
                        TextField("Content", text: $editedContent)
                    }

                    Section {
                        Button("Save") {
                            saveChanges()
                        }
                    }
                }
                .navigationTitle("Edit Task")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    editedTitle = task!.title
                    editedContent = task!.content
                }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    func saveChanges() {
        guard task != nil else { return }

        let realm = try! Realm()
        var didModify = false

        try! realm.write {
            if task!.title != editedTitle {
                task!.title = editedTitle
                task!.isTitleModified = true
                didModify = true
            }

            if task!.content != editedContent {
                task!.content = editedContent
                task!.isContentModified = true
                didModify = true
            }
            
            if conflictStrategy == "VV" {
                let deviceId = DeviceManager.shared.id
                let currentCount = task?.versionVector[deviceId] ?? 0
                task?.versionVector[deviceId] = currentCount + 1

            }

            if didModify {
                task!.lastModified = Date()
                NotificationCenter.default.post(name: Notification.Name("TaskUpdated"), object: nil)
            }
        }

        task = nil  // ✅ Binding 被解除，sheet 自動關閉
    }

}

