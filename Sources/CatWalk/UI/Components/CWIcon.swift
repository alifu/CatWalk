#if CATWALK_ENABLED
//
//  CWIcon.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// The CatWalk app icon (vector PDF in the package's asset catalog).
enum CWIcon {

    static let name = "CatWalkIcon"

    static var image: UIImage? {
        UIImage(named: name, in: .module, compatibleWith: nil)
    }

    static var swiftUIImage: Image {
        Image(name, bundle: .module)
    }
}
#endif
