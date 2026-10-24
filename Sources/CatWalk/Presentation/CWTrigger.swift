//
//  CWTrigger.swift
//  CatWalk
//

/// Gestures and overlays that open the inspector. `[]` (`.manual`) means only your own code does,
/// through `CatWalk.present()`, `CatWalk.makeViewController()` or `.catWalk(isPresented:)`.
public struct CWTrigger: OptionSet, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Shaking the device. Installs a one-time `UIWindow.motionEnded` hook that calls the original.
    public static let shake = CWTrigger(rawValue: 1 << 0)

    /// A draggable button over the app showing the number of captured requests.
    public static let floatingBubble = CWTrigger(rawValue: 1 << 1)

    public static let manual: CWTrigger = []
}
