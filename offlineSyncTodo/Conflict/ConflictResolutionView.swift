//
//  ConflictResolutionView.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 01/07/2025.
//


import SwiftUI

struct ConflictResolutionView: View {
    @ObservedObject var conflictCenter = ConflictCenter.shared
    @State private var selectedPair: ConflictPair? = nil

    var body: some View {
        List {
            ForEach(conflictCenter.conflicts) { pair in
                VStack(alignment: .leading) {
                    Text("Conflict for task: \(pair.local.title)")
                        .font(.headline)

                    Text("Local: \(pair.local.content)")
                        .foregroundColor(.blue)

                    Text("Remote: \(pair.remote.content)")
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 1)
                .onTapGesture {
                    selectedPair = pair
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Resolve Conflicts")
        .sheet(item: $selectedPair) { pair in
            ConflictDetailSheet(pair: pair) {
                selectedPair = nil
            }
        }
    }
}


struct ConflictDetailSheet: View {
    let pair: ConflictPair
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Local Version")
                        .font(.headline)
                    Text(pair.local.title)
                    Text(pair.local.content)
                        .foregroundColor(.blue)
                        .padding(.bottom)
                }

                VStack(alignment: .leading) {
                    Text("Remote Version")
                        .font(.headline)
                    Text(pair.remote.title)
                    Text(pair.remote.content)
                        .foregroundColor(.red)
                        .padding(.bottom)
                }

                HStack(spacing: 16) {
                    Button("Use Local") {
                        ConflictResolver.resolve(pair: pair, useRemote: false)
                        ConflictCenter.shared.removeConflict(pair)
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Use Remote") {
                        ConflictResolver.resolve(pair: pair, useRemote: true)
                        ConflictCenter.shared.removeConflict(pair)
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Resolve Conflict")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
    }
}

