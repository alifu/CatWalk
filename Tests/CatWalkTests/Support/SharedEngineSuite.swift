//
//  SharedEngineSuite.swift
//  CatWalk
//

import Testing

/// Parent of every suite that touches process-wide state: `CWCaptureEngine.shared`, its store,
/// `StubURLProtocol`'s stub table, or UIKit presentation. Nested suites run one at a time, so one
/// suite's `start`/`stop`/`reset` cannot break another running in parallel.
@Suite("Shared engine", .serialized)
enum SharedEngine {}
