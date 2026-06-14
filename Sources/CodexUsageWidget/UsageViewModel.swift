import CodexUsageCore
import Combine
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    private enum DefaultsKey {
        static let pinned = "panel.pinned"
        static let refreshIntervalMinutes = "refresh.interval.minutes"
        static let launchAtLogin = "launch.at.login.requested"
        static let showsSevenDayUsage = "panel.showsSevenDayUsage"
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
    @Published var showsSevenDayUsage: Bool {
        didSet {
            UserDefaults.standard.set(showsSevenDayUsage, forKey: DefaultsKey.showsSevenDayUsage)
            onShowsSevenDayUsageChanged?(showsSevenDayUsage)
        }
    }
    @Published private(set) var launchAtLogin: Bool

    var onPinnedChanged: ((Bool) -> Void)?
    var onShowsSevenDayUsageChanged: ((Bool) -> Void)?

    private let repository: UsageRepository
    private var refreshTask: Task<Void, Never>?
    private var statusTextTask: Task<Void, Never>?

    init(repository: UsageRepository = UsageRepository()) {
        self.repository = repository
        let cached = CacheStore().load()
        self.snapshot = cached ?? .empty
        self.pinned = UserDefaults.standard.object(forKey: DefaultsKey.pinned) as? Bool ?? true
        self.showsSevenDayUsage = UserDefaults.standard.object(forKey: DefaultsKey.showsSevenDayUsage) as? Bool ?? true
        let savedInterval = UserDefaults.standard.integer(forKey: DefaultsKey.refreshIntervalMinutes)
        self.refreshIntervalMinutes = savedInterval == 0 ? 5 : savedInterval.clamped(to: 1...60)
        self.launchAtLogin = UserDefaults.standard.object(forKey: DefaultsKey.launchAtLogin) as? Bool
            ?? LaunchAtLoginController.isEnabled
    }

    deinit {
        refreshTask?.cancel()
        statusTextTask?.cancel()
    }

    func start() {
        refresh()
        restartTimer()
        restartStatusTextTimer()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusText = "刷新中"

        Task {
            let nextSnapshot = await repository.refresh()
            snapshot = nextSnapshot
            isRefreshing = false
            updateStatusText()
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

    private func restartStatusTextTimer() {
        statusTextTask?.cancel()
        statusTextTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.updateStatusText()
            }
        }
    }

    private func updateStatusText(now: Date = Date()) {
        guard !isRefreshing else { return }

        let elapsed = max(0, Int(now.timeIntervalSince(snapshot.updatedAt)))
        let suffix = snapshot.isStale ? "缓存" : "更新"

        switch elapsed {
        case 0..<60:
            statusText = "刚刚\(suffix)"
        case 60..<3_600:
            statusText = "\(elapsed / 60) 分钟前\(suffix)"
        case 3_600..<86_400:
            statusText = "\(elapsed / 3_600) 小时前\(suffix)"
        default:
            statusText = "\(elapsed / 86_400) 天前\(suffix)"
        }
    }
}
