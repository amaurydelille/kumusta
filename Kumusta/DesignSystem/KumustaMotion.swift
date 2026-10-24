import SwiftUI

enum KumustaMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.68)
    static let screen = Animation.spring(response: 0.46, dampingFraction: 0.86)
    static let celebrate = Animation.spring(response: 0.55, dampingFraction: 0.62)
    static let breathe = Animation.easeInOut(duration: 1.8)
}

struct TactilePressModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.975 : 1))
            .brightness(isPressed ? -0.025 : 0)
            .animation(KumustaMotion.press, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

extension View {
    func tactile() -> some View {
        modifier(TactilePressModifier())
    }
}
