import AppKit
import Testing
import WebKit
@testable import ShowMermaid

@Suite(.serialized)
@MainActor
struct DiagramWebViewTests {
    @Test func zoomKeysAndModifiers() throws {
        let webView = DiagramWebView(frame: .zero, configuration: WKWebViewConfiguration())
        #expect(webView.allowsMagnification)

        #expect(webView.handleNavigationKey(key("+", modifiers: .shift)))
        #expect(abs(webView.magnification - 1.2) < 0.001)
        #expect(webView.handleNavigationKey(key("=")))
        #expect(webView.magnification == 1)
        #expect(webView.handleNavigationKey(key("+", modifiers: .shift)))
        #expect(webView.handleNavigationKey(key("-")))
        #expect(abs(webView.magnification - 1) < 0.001)

        for modifier: NSEvent.ModifierFlags in [.command, .control, .option] {
            #expect(!webView.handleNavigationKey(key("+", modifiers: modifier)))
            #expect(!webView.handleNavigationKey(key("0", modifiers: modifier)))
            #expect(!webView.handleNavigationKey(key("=", modifiers: modifier)))
        }
        #expect(!webView.handleNavigationKey(key("q")))
        #expect(abs(webView.magnification - 1) < 0.001)

        for _ in 0..<30 { _ = webView.handleNavigationKey(key("+")) }
        #expect(webView.magnification == 10)
        for _ in 0..<50 { _ = webView.handleNavigationKey(key("-")) }
        #expect(webView.magnification == 0.25)
        #expect(webView.handleNavigationKey(key("0")))
        #expect(webView.magnification == 1)
    }

    @Test func equalSignFitsAllContentWithoutScrolling() async throws {
        let (window, webView) = try await renderedViewer()
        defer { window.close() }
        try await expectFitted(webView)

        for magnification in [3.0, 0.5] {
            webView.setMagnification(magnification, centeredAt: .zero)
            try await wait(webView, until: "visualViewport.scale === \(magnification)")
            try await webView.evaluateJavaScript("window.scrollTo(100, 100)")
            #expect(webView.handleNavigationKey(key("=")))
            try await wait(webView, until: "visualViewport.scale === 1 && scrollX === 0 && scrollY === 0")
            try await expectFitted(webView)
        }
    }

    @Test func panAndResetRenderedDiagrams() async throws {
        let (window, webView) = try await renderedViewer()
        defer { window.close() }
        webView.setMagnification(2, centeredAt: .zero)
        try await wait(webView, until: "visualViewport.scale === 2")
        try await webView.evaluateJavaScript("window.scrollTo(0, 0)")

        #expect(webView.handleNavigationKey(arrow(.rightArrow)))
        #expect(webView.handleNavigationKey(arrow(.downArrow)))
        try await wait(webView, until: "scrollX > 0 && scrollY > 0")
        let x = try #require(try await webView.evaluateJavaScript("scrollX") as? Double)
        let y = try #require(try await webView.evaluateJavaScript("scrollY") as? Double)
        #expect(abs(x * webView.magnification - 60) <= 2)
        #expect(abs(y * webView.magnification - 60) <= 2)

        #expect(webView.handleNavigationKey(arrow(.leftArrow)))
        #expect(webView.handleNavigationKey(arrow(.upArrow)))
        try await wait(webView, until: "scrollX === 0 && scrollY === 0")

        // Key repeats continue to pan rather than only responding to the first press.
        for _ in 0..<3 {
            #expect(webView.handleNavigationKey(arrow(.rightArrow)))
            #expect(webView.handleNavigationKey(arrow(.downArrow)))
        }
        try await wait(webView, until: "scrollX >= 89 && scrollY >= 89")
        #expect(webView.handleNavigationKey(key("0")))
        try await wait(webView, until: "visualViewport.scale === 1 && scrollX === 0 && scrollY === 0")
    }

    @Test func resizingRestoresResponsiveFit() async throws {
        let (window, webView) = try await renderedViewer()
        defer { window.close() }
        webView.setMagnification(3, centeredAt: .zero)
        try await wait(webView, until: "visualViewport.scale === 3")
        try await webView.evaluateJavaScript("window.scrollTo(100, 100)")

        window.setContentSize(NSSize(width: 600, height: 400))
        try await wait(webView, until: "visualViewport.scale === 1 && scrollX === 0 && scrollY === 0 && innerWidth === 600")
        #expect(webView.magnification == 1)
        try await expectFitted(webView)
    }

    private func expectFitted(_ webView: WKWebView) async throws {
        try await wait(webView, until: """
            document.documentElement.scrollWidth <= document.documentElement.clientWidth &&
            document.documentElement.scrollHeight <= document.documentElement.clientHeight &&
            [...document.querySelectorAll('.diagram svg')].every(svg => {
                const rect = svg.getBoundingClientRect();
                return rect.width > 0 && rect.left >= 0 && rect.right <= innerWidth &&
                    rect.top >= 0 && rect.bottom <= innerHeight;
            })
            """)
    }

    private func key(_ characters: String, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: 0
        )!
    }

    private func arrow(_ specialKey: NSEvent.SpecialKey) -> NSEvent {
        key(String(UnicodeScalar(specialKey.rawValue)!))
    }

    private func renderedViewer() async throws -> (NSWindow, DiagramWebView) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let configuration = WKWebViewConfiguration()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let mermaid = try String(contentsOf: root.appendingPathComponent("Vendor/mermaid.min.js"), encoding: .utf8)
        let diagrams = [
            "flowchart LR\n" + (0..<12).map { "N\($0)[Node \($0)] --> N\($0 + 1)" }.joined(separator: "\n"),
            "flowchart TD\n" + (0..<12).map { "N\($0)[Node \($0)] --> N\($0 + 1)" }.joined(separator: "\n"),
        ]
        let json = String(data: try JSONEncoder().encode(diagrams), encoding: .utf8)!
        for source in [mermaid, "window.diagrams = \(json);"] {
            configuration.userContentController.addUserScript(WKUserScript(
                source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true
            ))
        }
        let webView = DiagramWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 750), configuration: configuration)
        let window = NSWindow(contentRect: webView.frame, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFront(nil)
        webView.loadHTMLString(Page.html, baseURL: nil)
        try await wait(webView, until: "document.querySelectorAll('.diagram svg').length === 2")
        return (window, webView)
    }

    private func wait(_ webView: WKWebView, until condition: String) async throws {
        for _ in 0..<200 {
            if (try await webView.evaluateJavaScript(condition)) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("Web view did not reach: \(condition)")
        throw CancellationError()
    }
}
