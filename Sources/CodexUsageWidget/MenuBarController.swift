import AppKit
import CodexUsageCore
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: UsageViewModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindViewModel()
        updateStatusItem()
        updatePopoverSize()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.action = #selector(togglePopover(_:))
        button.target = self
        button.image = menuBarIcon()
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(viewModel: viewModel, surface: .menuBar)
        )
    }

    private func bindViewModel() {
        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                    self?.updatePopoverSize()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        if viewModel.isRefreshing, displayWindow == nil {
            button.title = " ..."
            button.toolTip = "Codex 用量：刷新中"
            return
        }

        guard let window = displayWindow else {
            button.title = " --"
            button.toolTip = "Codex 用量：等待刷新"
            return
        }

        let resetText = resetText(for: window)
        button.title = " \(window.remainingPercent)% \(resetText)"
        button.toolTip = "Codex \(windowTitle(for: window.kind))剩余 \(window.remainingPercent)%，\(resetText) 重置"
    }

    private func updatePopoverSize() {
        popover.contentSize = NSSize(
            width: UsageWidgetLayout.width,
            height: viewModel.showsSevenDayUsage ? UsageWidgetLayout.expandedHeight : UsageWidgetLayout.compactHeight
        )
    }

    private var displayWindow: RateWindow? {
        viewModel.snapshot.fiveHour ?? viewModel.snapshot.weekly
    }

    private func resetText(for window: RateWindow) -> String {
        Formatters.quotaResetText(for: window) ?? "--:--"
    }

    private func menuBarIcon() -> NSImage? {
        if let codexURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            let resourcesURL = codexURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
            if let image = templateIcon(in: resourcesURL) {
                return resizedIcon(image, isTemplate: true)
            }
        }

        let codexAppPath = "/Applications/Codex.app"
        if FileManager.default.fileExists(atPath: codexAppPath) {
            let resourcesURL = URL(fileURLWithPath: codexAppPath)
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
            if let image = templateIcon(in: resourcesURL) {
                return resizedIcon(image, isTemplate: true)
            }
        }

        if let image = NSImage(systemSymbolName: "c.circle.fill", accessibilityDescription: "Codex 用量") {
            return resizedIcon(image, isTemplate: true)
        }

        return nil
    }

    private func templateIcon(in resourcesURL: URL) -> NSImage? {
        let iconNames = [
            "chatgptTemplate@2x",
            "chatgptTemplate",
            "codexTemplate@2x",
            "codexTemplate"
        ]
        for iconName in iconNames {
            let url = resourcesURL.appendingPathComponent(iconName).appendingPathExtension("png")
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private func resizedIcon(_ image: NSImage, isTemplate: Bool) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 16, height: 16)
        copy.isTemplate = isTemplate
        return copy
    }

    private func windowTitle(for kind: RateWindowKind) -> String {
        switch kind {
        case .fiveHour:
            return "5 小时额度"
        case .weekly:
            return "本周额度"
        case .unknown:
            return "额度"
        }
    }
}
