//
//  MainViewModel.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 08/07/26.
//

import Foundation

class MainViewModel: ObservableObject {

    @Published private(set) var logs: [APILogModel] = []

    @MainActor func reload() {
        logs = SecureFileStorage.shared.fetchAllLogs()
    }
}
