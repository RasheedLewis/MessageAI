import SwiftUI

extension Font {
    static let theme = AppFontTheme()
}

struct AppFontTheme {
    let display = Font.custom("Satoshi-Bold", size: 48, relativeTo: .largeTitle)
    let headline = Font.custom("Satoshi-Medium", size: 28, relativeTo: .title)
    let subhead = Font.custom("Satoshi-Medium", size: 20, relativeTo: .title3)
    let body = Font.custom("Inter-Regular", size: 16, relativeTo: .body)
    let bodyMedium = Font.custom("Inter-Medium", size: 16, relativeTo: .body)
    let caption = Font.custom("Inter-Regular", size: 13, relativeTo: .caption)
    let captionMedium = Font.custom("Inter-Medium", size: 13, relativeTo: .caption)
    let headline17 = Font.custom("Satoshi-Medium", size: 17)
    let subtitle14 = Font.custom("Inter-Regular", size: 14)
    let timestamp13 = Font.custom("Inter-Regular", size: 13)
    let button = Font.custom("Satoshi-Medium", size: 16, relativeTo: .body)
    let navTitle = Font.custom("Satoshi-Medium", size: 28)
}


