//
//  CWConfigurationError.swift
//  CatWalk
//

/// Invalid input passed to the CatWalk configuration API.
public enum CWConfigurationError: Error, Sendable, Equatable {
    /// The host rule is empty, malformed, or too broad (e.g. `*.com`).
    case invalidHost(String)
}
