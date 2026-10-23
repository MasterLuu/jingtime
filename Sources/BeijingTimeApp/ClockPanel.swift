import AppKit
import BeijingTimeCore

enum ClockMetrics {
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 8

    /// 数字等宽，星期都是一个汉字，所以样例有多宽，任何时刻就有多宽。
    static func sample(showsMilliseconds: Bool) -> String {
        showsMilliseconds ? "2026年01月05日 周一 09:05:03 0" : "2026年01月05日 周一 09:05:03"
    }

    static func windowSize(showsMilliseconds: Bool) -> NSSize {
        let text = (sample(showsMilliseconds: showsMilliseconds) as NSString).size(withAttributes: [.font: font])
        return NSSize(
            width: ceil(text.width) + horizontalPadding * 2,
            height: ceil(text.height) + verticalPadding * 2
        )
    }
}

/// 系统菜单的窗口层级低于这块面板，右键因此用自己的小窗。
final class ClockPanel: NSPanel {
    var onDragBegan: () -> Void = {}
    var onDrag: (CGPoint) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onMenu: (CGPoint) -> Void = { _ in }

    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureOverlayPanel(self)
        isMovable = false
        isRestorable = false
        becomesKeyOnlyIfNeeded = true
        let view = ClockView(frame: NSRect(origin: .zero, size: contentSize))
        view.autoresizingMask = [.width, .height]
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(text: String, reduceTransparency: Bool) {
        (contentView as? ClockView)?.show(text: text, reduceTransparency: reduceTransparency)
    }
}

final class ClockView: NSView {
    private static let attributes: [NSAttributedString.Key: Any] = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return [
            .font: ClockMetrics.font,
            .foregroundColor: NSColor(calibratedWhite: FixedFace.text.white, alpha: FixedFace.text.alpha),
            .paragraphStyle: style,
        ]
    }()
    /// 显示毫秒时每秒画 10 次，行高只量一次：字号固定，任何时刻的行高都和样例一样。
    private static let textHeight = (ClockMetrics.sample(showsMilliseconds: false) as NSString)
        .size(withAttributes: attributes).height

    private var text = ClockMetrics.sample(showsMilliseconds: false)
    private var reduceTransparency = false

    override var isOpaque: Bool { false }

    func show(text: String, reduceTransparency: Bool) {
        guard text != self.text || reduceTransparency != self.reduceTransparency else { return }
        self.text = text
        self.reduceTransparency = reduceTransparency
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let face = FixedFace.background(reduceTransparency: reduceTransparency)
        NSColor(calibratedWhite: face.white, alpha: face.alpha).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()

        let rect = NSRect(
            x: 0,
            y: ((bounds.height - ClockView.textHeight) / 2).rounded(.down),
            width: bounds.width,
            height: ceil(ClockView.textHeight)
        )
        (text as NSString).draw(in: rect, withAttributes: ClockView.attributes)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            (window as? ClockPanel)?.onMenu(NSEvent.mouseLocation)
            return
        }
        guard let window else { return }
        let startMouse = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var moved = false
        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: .infinity,
            mode: .eventTracking
        ) { event, stop in
            guard let event else { return }
            if event.type == .leftMouseUp {
                stop.pointee = true
                if moved {
                    NSCursor.pop()
                    (window as? ClockPanel)?.onDragEnded()
                }
                return
            }
            let mouse = NSEvent.mouseLocation
            let proposed = CGPoint(
                x: startOrigin.x + mouse.x - startMouse.x,
                y: startOrigin.y + mouse.y - startMouse.y
            )
            if !moved {
                moved = true
                NSCursor.closedHand.push()
                (window as? ClockPanel)?.onDragBegan()
            }
            (window as? ClockPanel)?.onDrag(proposed)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        (window as? ClockPanel)?.onMenu(NSEvent.mouseLocation)
    }
}

final class ActionMenu: NSPanel {
    enum Action {
        case hide
        case reset
        case toggleMilliseconds
        case quit
    }

    var onSelect: (Action) -> Void = { _ in }

    var showsMilliseconds = false {
        didSet {
            (contentView as? MenuView)?.items = MenuView.items(showsMilliseconds: showsMilliseconds)
        }
    }

    init() {
        let size = MenuView.preferredSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureOverlayPanel(self)
        let view = MenuView(frame: NSRect(origin: .zero, size: size))
        view.onSelect = { [weak self] action in self?.onSelect(action) }
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct MenuItem {
    var title: String
    var action: ActionMenu.Action
}

private func configureOverlayPanel(_ panel: NSPanel) {
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.sharingType = .readOnly
    panel.isExcludedFromWindowsMenu = true
    panel.animationBehavior = .none
    panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
    panel.collectionBehavior = [
        .canJoinAllSpaces,
        .canJoinAllApplications,
        .fullScreenAuxiliary,
        .stationary,
        .ignoresCycle,
    ]
}

private final class MenuView: NSView {
    static func items(showsMilliseconds: Bool) -> [MenuItem] {
        [
            MenuItem(title: "隐藏", action: .hide),
            MenuItem(title: "回到默认位置", action: .reset),
            MenuItem(title: showsMilliseconds ? "隐藏毫秒" : "显示毫秒", action: .toggleMilliseconds),
            MenuItem(title: "退出", action: .quit),
        ]
    }
    static let rowHeight: CGFloat = 32
    static let font = NSFont.systemFont(ofSize: 13, weight: .medium)

    /// 两种文案都量一遍，切换毫秒时菜单不用改尺寸。
    static var preferredSize: NSSize {
        let all = items(showsMilliseconds: false) + items(showsMilliseconds: true)
        let widest = all.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 80
        return NSSize(width: ceil(widest) + 36, height: rowHeight * CGFloat(items(showsMilliseconds: false).count))
    }

    var onSelect: (ActionMenu.Action) -> Void = { _ in }
    var items = MenuView.items(showsMilliseconds: false) {
        didSet { needsDisplay = true }
    }
    private var highlight: Int?

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        path.fill()
        path.addClip()

        if let highlight, items.indices.contains(highlight) {
            NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
            NSBezierPath(rect: rowRect(highlight)).fill()
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: MenuView.font,
            .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1),
            .paragraphStyle: style,
        ]
        for (index, item) in items.enumerated() {
            let row = rowRect(index)
            let textSize = (item.title as NSString).size(withAttributes: attributes)
            let textRect = NSRect(
                x: 16,
                y: row.minY + ((row.height - textSize.height) / 2).rounded(.down),
                width: row.width - 24,
                height: ceil(textSize.height)
            )
            (item.title as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        setHighlight(row(at: event))
    }

    override func mouseExited(with event: NSEvent) {
        setHighlight(nil)
    }

    override func mouseUp(with event: NSEvent) {
        guard let row = row(at: event) else { return }
        onSelect(items[row].action)
    }

    private func setHighlight(_ row: Int?) {
        guard row != highlight else { return }
        highlight = row
        needsDisplay = true
    }

    private func row(at event: NSEvent) -> Int? {
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return nil }
        let index = Int((bounds.height - local.y) / MenuView.rowHeight)
        return items.indices.contains(index) ? index : nil
    }

    private func rowRect(_ index: Int) -> NSRect {
        NSRect(
            x: 0,
            y: bounds.height - CGFloat(index + 1) * MenuView.rowHeight,
            width: bounds.width,
            height: MenuView.rowHeight
        )
    }
}
