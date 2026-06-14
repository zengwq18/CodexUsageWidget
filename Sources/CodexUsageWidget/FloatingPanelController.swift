import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let width: CGFloat = 280
        static let expandedHeight: CGFloat = 148
        static let compactHeight: CGFloat = 94
    }

    private enum DefaultsKey {
        static let originX = "panel.origin.x"
        static let originY = "panel.origin.y"
    }

    private let panel: NSPanel
    private let viewModel: UsageViewModel

    init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
        let rect = Self.initialFrame(showsSevenDayUsage: viewModel.showsSevenDayUsage)
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
        setShowsSevenDayUsage(viewModel.showsSevenDayUsage)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func setPinned(_ pinned: Bool) {
        panel.level = pinned ? .floating : .normal
    }

    func setShowsSevenDayUsage(_ showsSevenDayUsage: Bool) {
        let height = Self.height(showsSevenDayUsage: showsSevenDayUsage)
        let topY = panel.frame.maxY
        panel.setContentSize(NSSize(width: Layout.width, height: height))

        var frame = panel.frame
        frame.origin.y = topY - frame.height
        panel.setFrame(frame, display: true)
    }

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.originX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.originY)
    }

    private static func initialFrame(showsSevenDayUsage: Bool) -> NSRect {
        let size = NSSize(
            width: Layout.width,
            height: height(showsSevenDayUsage: showsSevenDayUsage)
        )
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

    private static func height(showsSevenDayUsage: Bool) -> CGFloat {
        showsSevenDayUsage ? Layout.expandedHeight : Layout.compactHeight
    }
}
