import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private enum DefaultsKey {
        static let originX = "panel.origin.x"
        static let originY = "panel.origin.y"
    }

    private let panel: NSPanel
    private let viewModel: UsageViewModel

    init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
        let rect = Self.initialFrame()
        self.panel = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.title = "Codex Usage"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: ContentView(viewModel: viewModel))

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        setPinned(viewModel.pinned)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func setPinned(_ pinned: Bool) {
        panel.level = pinned ? .floating : .normal
    }

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.originX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.originY)
    }

    private static func initialFrame() -> NSRect {
        let size = NSSize(width: 280, height: 148)
        let defaults = UserDefaults.standard
        if defaults.object(forKey: DefaultsKey.originX) != nil,
           defaults.object(forKey: DefaultsKey.originY) != nil {
            return NSRect(
                x: defaults.double(forKey: DefaultsKey.originX),
                y: defaults.double(forKey: DefaultsKey.originY),
                width: size.width,
                height: size.height
            )
        }

        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSRect(
            x: visible.maxX - size.width - 24,
            y: visible.maxY - size.height - 48,
            width: size.width,
            height: size.height
        )
    }
}
