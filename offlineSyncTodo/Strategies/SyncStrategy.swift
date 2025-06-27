//
//  SyncStrategy.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 20/05/2025.
//


import Foundation
import RealmSwift

protocol SyncStrategy {
    func sync(completion: @escaping (SyncReport) -> Void)
}
