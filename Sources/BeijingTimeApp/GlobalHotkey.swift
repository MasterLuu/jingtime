import Carbon
import Foundation

/// `⌃⌥T`。系统弹出菜单的层级比悬浮时钟低，所以快捷键走 Carbon，不走菜单快捷键。
final class GlobalHotkey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onPress: () -> Void

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    func install() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            handleHotkey,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(controlKey | optionKey),
            EventHotKeyID(signature: fourChar("BJTM"), id: 1),
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    fileprivate func fire() {
        onPress()
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let handler {
            RemoveEventHandler(handler)
        }
    }
}

private func handleHotkey(
    _: EventHandlerCallRef?,
    _: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue().fire()
    return noErr
}

private func fourChar(_ code: String) -> OSType {
    var value: OSType = 0
    for byte in code.utf8.prefix(4) {
        value = (value << 8) + OSType(byte)
    }
    return value
}
