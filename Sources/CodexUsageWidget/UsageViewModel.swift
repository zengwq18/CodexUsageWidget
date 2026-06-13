import CodexUsageCore
import Combine
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    private enum DefaultsKey {
        static let pinned = "panel.pinned"
        static let refreshIntervalMinutes = "refresh.interval.minutes"
        static let launchAtLogin = "launch.at.login.requested"
    }

    @Published private(set) var snapshot: UsageSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusText = "准备刷新"
    @Published var pinned: Bool {
        didSet {
            UserDefaults.standard.set(pinned, forKey: DefaultsKey.pinned)
            onPinnedChanged?(pinned)
        }
    }
    @Published var refreshIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: DefaultsKey.refreshIntervalMinutes)
            restartTimer()
        }
    }
    @Published private(set) var launchAtLogin: Bool

    var onPinnedChanged: ((Bool) -> Void)?

    private let repository: UsageRepository
    private var refreshTask: Task<Void, Never>?

    init(repository: UsageRepository = UsageRepository()) {
        self.repository = repository
        let cached = CacheStore().load()
        self.snapshot = cached ?? .empty
        self.pinned = UserDefaults.standard.object(forKey: DefaultsKey.pinned) as? Bool ?? true
        let savedInterval = UserDefaults.standard.integer(forKey: DefaultsKey.refreshIntervalMinutes)
        self.refreshIntervalMinutes = savedInterval == 0 ? 5 : savedInterval.clamped(to: 1...60)
        self.launchAtLogin = UserDefaults.standard.object(forKey: DefaultsKey.launchAtLogin) as? Bool
            ?? LaunchAtLoginController.isEnabled
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        refresh()
        restartTimer()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusText = "刷新中"

        Task {
            let nextSnapshot = await repository.refresh()
            snapshot = nextSnapshot
            isRefreshing = false
            statusText = nextSnapshot.isStale ? "本地缓存" : "刚刚更新"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            launchAtLogin = enabled
            UserDefaults.standard.set(enabled, forKey: DefaultsKey.launchAtLogin)
        } catch {
            launchAtLogin = LaunchAtLoginController.isEnabled
            statusText = "开机启动设置失败"
        }
    }

    private func restartTimer() {
        refreshTask?.cancel()
        let interval = UInt64(refreshIntervalMinutes * 60)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
                self?.refresh()
            }
        }
    }
}
