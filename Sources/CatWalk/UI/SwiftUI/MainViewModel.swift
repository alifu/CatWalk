//
//  MainViewModel.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 08/07/26.
//

import Foundation

@MainActor
final class MainViewModel: ObservableObject {

    @Published private(set) var transactions: [CWTransaction] = []

    private let store: CWTransactionStore

    init(store: CWTransactionStore = CWCaptureEngine.shared.store) {
        self.store = store
    }

    func reload() {
        transactions = store.snapshot()
    }
}
