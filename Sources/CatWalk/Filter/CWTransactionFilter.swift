#if CATWALK_ENABLED
//
//  CWTransactionFilter.swift
//  CatWalk
//

import Foundation

/// Coarse outcome of a transaction, as used by the filter chips.
enum CWStatusClass: CaseIterable, Hashable, Sendable {
    case success, redirect, clientError, serverError, failed

    /// `nil` while the request is still in flight.
    init?(_ transaction: CWTransaction) {
        if let code = transaction.response?.statusCode {
            switch code {
            case 200..<300: self = .success
            case 300..<400: self = .redirect
            case 400..<500: self = .clientError
            case 500..<600: self = .serverError
            default: self = .failed
            }
        } else if transaction.error != nil {
            self = .failed
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .success: "2xx"
        case .redirect: "3xx"
        case .clientError: "4xx"
        case .serverError: "5xx"
        case .failed: "Error"
        }
    }
}

/// Which transactions the list shows. An empty criterion matches everything.
struct CWTransactionFilter: Equatable, Sendable {

    var searchText = ""
    var methods: Set<String> = []
    var statusClasses: Set<CWStatusClass> = []
    var mockedOnly = false
    var host: String?
    var source: CWTransaction.Source?
    /// Rows the user swiped away; the store keeps them, the list hides them.
    var hiddenIDs: Set<UUID> = []

    /// Whether any criterion narrows the list (hidden rows do not count).
    var isActive: Bool {
        !trimmedSearch.isEmpty || !methods.isEmpty || !statusClasses.isEmpty || mockedOnly || host != nil
            || source != nil
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// O(n) over `transactions`, keeping their order.
    func apply(to transactions: [CWTransaction]) -> [CWTransactionFilter.Element] {
        let query = trimmedSearch
        return transactions.filter { transaction in
            !hiddenIDs.contains(transaction.id)
                && (query.isEmpty || transaction.searchKey.contains(query))
                && (methods.isEmpty || methods.contains(transaction.request.method.uppercased()))
                && (statusClasses.isEmpty || CWStatusClass(transaction).map(statusClasses.contains) == true)
                && (!mockedOnly || transaction.isMocked)
                && (host == nil || transaction.request.url.host?.lowercased() == host)
                && (source == nil || transaction.source == source)
        }
    }

    typealias Element = CWTransaction

    func clearingCriteria() -> CWTransactionFilter {
        CWTransactionFilter(hiddenIDs: hiddenIDs)
    }

    static func hosts(in transactions: [CWTransaction]) -> [String] {
        Set(transactions.compactMap { $0.request.url.host?.lowercased() }).sorted()
    }
}
#endif
