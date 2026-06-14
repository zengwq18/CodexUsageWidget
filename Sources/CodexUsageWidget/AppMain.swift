import AppKit
import SwiftUI

@main
struct CodexUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = UsageViewModel()
    private var panelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = FloatingPanelController(viewModel: viewModel)
        self.panelController = panelController
        viewModel.onPinnedChanged = { [weak panelController] pinned in
            panelController?.setPinned(pinned)
        }
        viewModel.onShowsSevenDayUsageChanged = { [weak panelController] showsSevenDayUsage in
            panelController?.setShowsSevenDayUsage(showsSevenDayUsage)
        }

        panelController.show()
        viewModel.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
