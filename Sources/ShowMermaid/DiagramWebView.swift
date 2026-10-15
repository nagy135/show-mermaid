import AppKit
import WebKit

@MainActor
final class DiagramWebView: WKWebView {
    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        allowsMagnification = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Keep the responsive page layout as the starting point after a resize.
    override func setFrameSize(_ newSize: NSSize) {
        let resized = newSize != frame.size
        super.setFrameSize(newSize)
        if resized, magnification != 1 {
            resetView()
        }
    }

    /// Called by the local event monitor because WebKit's content view receives keys.
    func handleNavigationKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            return false
        }

        switch event.characters {
        case "+":
            zoom(by: 1.2)
        case "-":
            zoom(by: 1 / 1.2)
        case "=", "0":
            resetView()
        default:
            switch event.specialKey {
            case .rightArrow:
                pan(x: 60, y: 0)
            case .leftArrow:
                pan(x: -60, y: 0)
            case .downArrow:
                pan(x: 0, y: 60)
            case .upArrow:
                pan(x: 0, y: -60)
            default:
                return false
            }
        }
        return true
    }

    private func zoom(by factor: CGFloat) {
        setMagnification(
            min(10, max(0.25, magnification * factor)),
            centeredAt: NSPoint(x: bounds.midX, y: bounds.midY)
        )
    }

    private func resetView() {
        magnification = 1
        evaluateJavaScript("window.scrollTo(0, 0)", completionHandler: nil)
    }

    private func pan(x: CGFloat, y: CGFloat) {
        // Scroll coordinates are in CSS pixels; keep each key press the same
        // distance on screen at every magnification, including held-key repeats.
        evaluateJavaScript("window.scrollBy(\(x / magnification), \(y / magnification))", completionHandler: nil)
    }
}
