import SwiftUI

extension Animation {
    static func cubicBezier(_ p0x: Double, _ p0y: Double, _ p1x: Double, _ p1y: Double, duration: Double = 0.12) -> Animation {
        Animation.timingCurve(p0x, p0y, p1x, p1y, duration: duration)
    }
}


