//
//  DeviceManager.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 25/06/2025.
//


import Foundation

class DeviceManager {
    static let shared = DeviceManager()
    let id: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "deviceId") {
            self.id = saved
        } else {
            let newId = UUID().uuidString.prefix(6)  // 可簡短化 ID，例如 "devA12"
            UserDefaults.standard.set(String(newId), forKey: "deviceId")
            self.id = String(newId)
        }
    }
}
