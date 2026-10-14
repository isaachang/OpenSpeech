import Carbon

/// Carbon 全局快捷键：不需要辅助功能权限，在任何 App 前台都能用。
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var installed = false

    enum Key: UInt32 {
        case p = 35, period = 47, left = 123, right = 124, down = 125, up = 126
        case one = 18, two = 19, three = 20, four = 21, five = 23
    }

    func register(_ key: Key, modifiers: Int = cmdKey | optionKey, action: @escaping () -> Void) {
        installIfNeeded()
        let id = UInt32(handlers.count + 1)
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x4E43_4B59), id: id)
        let status = RegisterEventHotKey(key.rawValue, UInt32(modifiers), hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return }
        handlers[id] = action
        refs.append(ref)
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async { HotKeyCenter.shared.handlers[hk.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
