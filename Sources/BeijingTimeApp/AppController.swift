import AppKit
import Darwin
import ServiceManagement
import BeijingTimeCore

final class AppController: NSObject {
    private let store = StayStore()
    private let millisecondsStore = MillisecondsStore()
    private let sleeper = SecondSleeper()
    private let instance = SingleInstance()
    private var presence = Presence()
    private var showsMilliseconds = false
    private var panel: ClockPanel?
    private var menu: ActionMenu?
    private var hotkey: GlobalHotkey?
    private var dragging = false
    private var outsideMonitor: Any?
    private var localOutsideMonitor: Any?

    func claimInstance() -> Bool {
        instance.claim()
    }

    func start() {
        registerLoginItemIfInstalled()
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.loginwindow" {
            presence.locked = true
        }
        showsMilliseconds = millisecondsStore.load()
        let panel = ClockPanel(contentSize: ClockMetrics.windowSize(showsMilliseconds: showsMilliseconds))
        self.panel = panel
        panel.onDragBegan = { [weak self] in self?.dragging = true }
        panel.onDrag = { [weak self] origin in self?.drag(to: origin) }
        panel.onDragEnded = { [weak self] in self?.finishDrag() }
        panel.onMenu = { [weak self] point in self?.toggleMenu(at: point) }
        observeSystem()
        hotkey = GlobalHotkey { [weak self] in self?.toggleHide() }
        hotkey?.install()
        refresh()
    }

    private func refresh() {
        guard let panel else { return }
        if !dragging {
            reposition()
        }
        if presence.showsWindow {
            let now = Date()
            panel.show(
                text: MomentText.string(at: now, showsMilliseconds: showsMilliseconds),
                reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            )
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
            if presence.wakesEachSecond {
                sleeper.arm(now: now, showsMilliseconds: showsMilliseconds) { [weak self] in self?.tick() }
            } else {
                sleeper.disarm()
            }
        } else {
            closeMenu()
            panel.orderOut(nil)
            sleeper.disarm()
        }
    }

    private func tick() {
        guard presence.wakesEachSecond, let panel else {
            sleeper.disarm()
            return
        }
        let now = Date()
        panel.show(
            text: MomentText.string(at: now, showsMilliseconds: showsMilliseconds),
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
        sleeper.arm(now: now, showsMilliseconds: showsMilliseconds) { [weak self] in self?.tick() }
    }

    private func reposition() {
        guard let panel else { return }
        guard let resolved = Placement.resolve(
            stay: store.load(),
            among: LiveScreens.snapshot(),
            windowSize: panel.frame.size
        ) else { return }
        panel.setFrameOrigin(resolved.origin)
        if resolved.source.writesStay {
            store.save(resolved.stay)
        }
    }

    private func drag(to origin: CGPoint) {
        guard let panel else { return }
        let clamped = Placement.clamp(
            origin: origin,
            windowSize: panel.frame.size,
            to: LiveScreens.snapshot()
        )
        panel.setFrameOrigin(clamped)
    }

    private func finishDrag() {
        dragging = false
        guard let panel else { return }
        if let stay = Placement.stick(
            windowOrigin: panel.frame.origin,
            windowSize: panel.frame.size,
            among: LiveScreens.snapshot()
        ) {
            store.save(stay)
        }
    }

    private func toggleHide() {
        let next = presence.togglingHide()
        guard next != presence else { return }
        presence = next
        refresh()
    }

    private func resetToDefault() {
        guard presence.showsWindow, let panel else { return }
        guard let resolved = Placement.resolve(
            stay: nil,
            among: LiveScreens.snapshot(),
            windowSize: panel.frame.size
        ) else { return }
        panel.setFrameOrigin(resolved.origin)
        store.save(resolved.stay)
    }

    /// 时刻文本变宽变窄，小窗跟着变，守住靠近屏幕边的那一侧，并记成新的停留位置。
    private func toggleMilliseconds() {
        guard presence.showsWindow, let panel else { return }
        showsMilliseconds.toggle()
        millisecondsStore.save(showsMilliseconds)
        let size = ClockMetrics.windowSize(showsMilliseconds: showsMilliseconds)
        let screens = LiveScreens.snapshot()
        let origin = Placement.resize(origin: panel.frame.origin, from: panel.frame.size, to: size, among: screens)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        if let stay = Placement.stick(windowOrigin: origin, windowSize: size, among: screens) {
            store.save(stay)
        }
        refresh()
    }

    private func quit() {
        guard presence.canQuit else { return }
        NSApp.terminate(nil)
    }

    private func toggleMenu(at point: CGPoint) {
        if menu?.isVisible == true {
            closeMenu()
        }
        let menu = self.menu ?? ActionMenu()
        self.menu = menu
        menu.showsMilliseconds = showsMilliseconds
        menu.onSelect = { [weak self] action in self?.performMenu(action) }
        let origin = menuOrigin(at: point, size: menu.frame.size)
        menu.setFrameOrigin(origin)
        menu.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in self?.watchOutsideClicks() }
    }

    private func performMenu(_ action: ActionMenu.Action) {
        closeMenu()
        switch action {
        case .hide:
            toggleHide()
        case .reset:
            resetToDefault()
        case .toggleMilliseconds:
            toggleMilliseconds()
        case .quit:
            quit()
        }
    }

    private func menuOrigin(at mouse: CGPoint, size: CGSize) -> CGPoint {
        let screens = LiveScreens.snapshot()
        let screen = screens.first { $0.frame.contains(mouse) } ?? screens.first
        guard let screen else { return mouse }
        let margin: CGFloat = 4
        let x = min(max(mouse.x, screen.frame.minX + margin), screen.frame.maxX - size.width - margin)
        let y = min(max(mouse.y - size.height, screen.frame.minY + margin), screen.frame.maxY - size.height - margin)
        return CGPoint(x: x, y: y)
    }

    private func watchOutsideClicks() {
        closeOutsideMonitors()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeMenuIfOutside()
        }
        localOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeMenuIfOutside()
            return event
        }
    }

    private func closeMenuIfOutside() {
        guard let menu, menu.isVisible else { return }
        if menu.frame.contains(NSEvent.mouseLocation) { return }
        closeMenu()
    }

    private func closeMenu() {
        menu?.orderOut(nil)
        closeOutsideMonitors()
    }

    private func closeOutsideMonitors() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
            self.outsideMonitor = nil
        }
        if let localOutsideMonitor {
            NSEvent.removeMonitor(localOutsideMonitor)
            self.localOutsideMonitor = nil
        }
    }

    private func registerLoginItemIfInstalled() {
        guard Bundle.main.bundlePath == "/Applications/北京时间.app" else { return }
        guard SMAppService.mainApp.status != .enabled else { return }
        try? SMAppService.mainApp.register()
    }

    private func observeSystem() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked), name: Notification.Name("com.apple.screenIsLocked"), object: nil, suspensionBehavior: .deliverImmediately)
        distributed.addObserver(self, selector: #selector(screenUnlocked), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil, suspensionBehavior: .deliverImmediately)
        distributed.addObserver(self, selector: #selector(saverStarted), name: Notification.Name("com.apple.screensaver.didstart"), object: nil, suspensionBehavior: .deliverImmediately)
        distributed.addObserver(self, selector: #selector(saverStopped), name: Notification.Name("com.apple.screensaver.didstop"), object: nil, suspensionBehavior: .deliverImmediately)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc private func screenLocked() {
        presence.locked = true
        refresh()
    }

    @objc private func screenUnlocked() {
        presence.locked = false
        refresh()
    }

    @objc private func saverStarted() {
        presence.savingScreen = true
        refresh()
    }

    @objc private func saverStopped() {
        presence.savingScreen = false
        refresh()
    }

    @objc private func willSleep() {
        presence.asleep = true
        sleeper.disarm()
    }

    @objc private func didWake() {
        presence.asleep = false
        refresh()
    }

    @objc private func screensSlept() {
        presence.asleep = true
        sleeper.disarm()
    }

    @objc private func screensWoke() {
        presence.asleep = false
        refresh()
    }

    @objc private func screensChanged() {
        guard !dragging else { return }
        refresh()
    }

    @objc private func spaceChanged() {
        guard presence.showsWindow else { return }
        panel?.orderFrontRegardless()
    }

    @objc private func accessibilityChanged() {
        guard presence.showsWindow, let panel else { return }
        panel.show(
            text: MomentText.string(at: Date(), showsMilliseconds: showsMilliseconds),
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
    }
}

private final class SingleInstance {
    private var fd: Int32 = -1

    func claim() -> Bool {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/北京时间", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return true
        }
        fd = open(directory.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, 0o644)
        if fd < 0 { return true }
        return flock(fd, LOCK_EX | LOCK_NB) == 0
    }
}
