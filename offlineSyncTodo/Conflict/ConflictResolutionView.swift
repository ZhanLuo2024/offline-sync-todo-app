//
//  ConflictResolutionView.swift
//  offlineSyncTodo
//
//  Created by Luo HY on 01/07/2025.
//

import SwiftUI

struct ConflictResolutionView: View {
    @ObservedObject var conflictCenter = ConflictCenter.shared
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedPair: ConflictPair? = nil

    var body: some View {
        List {
            ForEach(conflictCenter.conflicts) { pair in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task: \(pair.local.title)")
                        .font(.headline)

                    HStack {
                        Text("Local:")
                            .bold()
                            .foregroundColor(.blue)
                        Text(pair.local.content)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Remote:")
                            .bold()
                            .foregroundColor(.red)
                        Text(pair.remote.content)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .onTapGesture {
                    selectedPair = pair
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Resolve Conflicts")
        .sheet(item: $selectedPair) { pair in
            ConflictDetailSheet(pair: pair, viewModel: viewModel) {
                selectedPair = nil
            }
        }
    }
}

struct ConflictDetailSheet: View {
    let pair: ConflictPair
    @ObservedObject var viewModel: MainViewModel
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Version")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Title: \(pair.local.title)")
                            .font(.subheadline)
                        Text("Content: \(pair.local.content)")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remote Version")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Title: \(pair.remote.title)")
                            .font(.subheadline)
                        Text("Content: \(pair.remote.content)")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        resolveConflict(useRemote: false)
                    } label: {
                        Text("Use Local")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        resolveConflict(useRemote: true)
                    } label: {
                        Text("Use Remote")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

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

    private func resolveConflict(useRemote: Bool) {
        ConflictResolver.resolve(pair: pair, useRemote: useRemote)
        ConflictCenter.shared.removeConflict(pair)

        // 如果已經沒有衝突了，通知主頁刷新
        if ConflictCenter.shared.conflicts.isEmpty {
            viewModel.onConflictResolved()
        }

        onClose()
    }
}
