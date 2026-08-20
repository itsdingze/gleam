import SwiftUI

extension Animation {
    static let mirrorExpand = Animation.bouncy(duration: 0.3, extraBounce: 0.05)

    static let mirrorCollapse = Animation.spring(duration: 0.3)
}
