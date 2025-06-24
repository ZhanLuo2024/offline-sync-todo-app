//
//  offlineSyncTodoApp.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 19/05/2025.
//

import SwiftUI

@main
struct offlineSyncTodoApp: App {
    init() {
        TaskRepository().generateDummyTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
