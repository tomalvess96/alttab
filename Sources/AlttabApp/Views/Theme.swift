import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.71, blue: 0.28) // #FFB547
    static let text = Color(red: 0.925, green: 0.929, blue: 0.937)
    static let muted = Color(red: 0.61, green: 0.63, blue: 0.67)
    static let cardFill = Color.white.opacity(0.035)
    static let cardStroke = Color.white.opacity(0.08)
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 12
    static let thumbRadius: CGFloat = 8
    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
}
