//
//  SyncLogger.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 27/06/2025.
//


import Foundation

struct SyncReport {
    let itemsSent: Int
    let itemsReceived: Int
    let duration: TimeInterval
    var payloadSize: Int
}

class SyncLogger {
    
    static func formatReport(mode: SyncMode, strategy: String, report: SyncReport) -> String {
        return """
        Sync successful
        Time: \(String(format: "%.2f", report.duration)) sec
        Payload Size: \(report.payloadSize) bytes
        Mode: \(mode.rawValue)
        Strategy: \(strategy)
        """
    }

    static func formatError(error: String) -> String {
        return """
        Sync Failed
        Reason: \(error)
        """
    }

    static func formatEmptyUpload() -> String {
        return "Nothing to upload."
    }
}
