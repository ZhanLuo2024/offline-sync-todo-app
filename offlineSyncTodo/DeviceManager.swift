//
//  DeviceManager.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 25/06/2025.
//


import Foundation

class DeviceManager {
    static let shared = DeviceManager()
    private(set) var id: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "deviceId") {
            self.id = saved
        } else {
            let newId = UUID().uuidString.prefix(6)
            UserDefaults.standard.set(String(newId), forKey: "deviceId")
            self.id = String(newId)
        }
    }
    
    // set device ID for VV test
    func setDeviceId(_ newId: String) {
        self.id = newId
        UserDefaults.standard.set(newId, forKey: "deviceId")
    }
}
