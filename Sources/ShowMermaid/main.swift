import AppKit
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let diagrams = MermaidExtractor.diagrams(in: clipboard)

        let webView = WKWebView(frame: .zero, configuration: Self.configuration(for: diagrams))
        webView.setValue(false, forKey: "drawsBackground") // avoid a white flash in dark mode
        webView.loadHTMLString(Page.html, baseURL: nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Show Mermaid"
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        // Plain "q" (no modifiers) quits, in addition to ⌘Q.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .control, .option])
            if modifiers.isEmpty, event.charactersIgnoringModifiers?.lowercased() == "q" {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }

        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Mermaid and the diagram sources are injected as user scripts rather than
    /// spliced into the HTML, so clipboard content can never break out of the page markup.
    private static func configuration(for diagrams: [String]) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let scripts = configuration.userContentController

        if let url = Bundle.main.url(forResource: "mermaid.min", withExtension: "js"),
           let mermaid = try? String(contentsOf: url, encoding: .utf8) {
            scripts.addUserScript(WKUserScript(source: mermaid, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        let json = (try? JSONEncoder().encode(diagrams)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        scripts.addUserScript(WKUserScript(source: "window.diagrams = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true))

        return configuration
    }
}

@MainActor
func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit Show Mermaid", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

    let mainMenu = NSMenu()
    for submenu in [appMenu, fileMenu] {
        let item = NSMenuItem()
        item.submenu = submenu
        mainMenu.addItem(item)
    }
    return mainMenu
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.mainMenu = makeMainMenu()
app.run()
