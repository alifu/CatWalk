#if CATWALK_ENABLED
//
//  CWIcon.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// The CatWalk mark: an SF Symbol, so the package ships no resource bundle.
enum CWIcon {

    static let symbolName = "pawprint.fill"

    static func image(pointSize: CGFloat) -> UIImage? {
        UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold))
    }

    static var swiftUIImage: Image {
        Image(systemName: symbolName)
    }
}
#endif
