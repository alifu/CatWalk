#if CATWALK_ENABLED
//
//  CWFloatingBubble.swift
//  CatWalk
//

import Combine
import UIKit

/// Window that only reacts to touches on the bubble; everything else reaches the app.
final class CWBubbleWindow: UIWindow {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === rootViewController?.view ? nil : hit
    }
}

/// Draggable button over the app with the live request count.
@MainActor
final class CWFloatingBubble {

    static let diameter: CGFloat = 52

    private let onTap: () -> Void
    private var window: CWBubbleWindow?
    private var button: UIButton?
    private var isHidden = false
    private var countObserver: AnyCancellable?
    private var activationObserver: NSObjectProtocol?

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    /// Shows the bubble now, or as soon as a scene is active (`start` usually runs before one exists).
    func install() {
        guard window == nil else { return }
        guard !attach() else { return }

        activationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.attach() }
        }
    }

    func remove() {
        window?.isHidden = true
        window = nil
        button = nil
        countObserver = nil
        activationObserver.map(NotificationCenter.default.removeObserver)
        activationObserver = nil
    }

    func setHidden(_ hidden: Bool) {
        isHidden = hidden
        window?.isHidden = hidden
    }

    @discardableResult
    private func attach() -> Bool {
        guard
            window == nil,
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        else {
            return false
        }
        let bubbleWindow = CWBubbleWindow(windowScene: scene)
        bubbleWindow.windowLevel = .alert + 1
        bubbleWindow.backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .clear
        bubbleWindow.rootViewController = root
        bubbleWindow.isHidden = isHidden

        let button = makeButton()
        root.view.addSubview(button)
        let bounds = scene.coordinateSpace.bounds
        button.frame = CGRect(
            x: bounds.width - Self.diameter - 8,
            y: bounds.height * 0.6,
            width: Self.diameter,
            height: Self.diameter
        )
        window = bubbleWindow
        self.button = button
        observeCount()
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
        return true
    }

    private func makeButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "network")
        configuration.imagePlacement = .top
        configuration.imagePadding = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
        configuration.baseBackgroundColor = .systemIndigo
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.onTap() })
        button.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        button.accessibilityLabel = "CatWalk network inspector"
        button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
        return button
    }

    private func observeCount() {
        let store = CWCaptureEngine.shared.store
        // Hop to main first: closures below are main-actor isolated and the store publishes on any thread.
        countObserver = store.changes
            .receive(on: DispatchQueue.main)
            .map { _ in () }
            .prepend(())
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.show(count: store.count) }
            }
    }

    private func show(count: Int) {
        button?.configuration?.title = count > 999 ? "999+" : String(count)
        button?.accessibilityValue = "\(count) requests"
    }

    @objc private func drag(_ gesture: UIPanGestureRecognizer) {
        guard let button, let container = button.superview else { return }
        let translation = gesture.translation(in: container)
        gesture.setTranslation(.zero, in: container)
        button.center = CGPoint(x: button.center.x + translation.x, y: button.center.y + translation.y)

        guard gesture.state == .ended || gesture.state == .cancelled else { return }
        let bounds = container.bounds
        let insets = container.safeAreaInsets
        let radius = Self.diameter / 2
        let x = button.center.x < bounds.midX ? radius + 8 : bounds.width - radius - 8
        let y = min(max(button.center.y, insets.top + radius), bounds.height - insets.bottom - radius)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            button.center = CGPoint(x: x, y: y)
        }
    }
}
#endif
