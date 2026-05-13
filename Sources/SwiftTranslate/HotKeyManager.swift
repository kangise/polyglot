import AppKit
import Carbon.HIToolbox

/// Registers a global hotkey (default ⌥⌘T) via the Carbon HotKey API.
final class HotKeyManager {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static var shared: HotKeyManager?

    func register(keyCode: UInt32 = UInt32(kVK_ANSI_T),
                  modifiers: UInt32 = UInt32(cmdKey | optionKey)) {
        HotKeyManager.shared = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            HotKeyManager.shared?.onTrigger?()
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let signature: OSType = 0x53575454 // 'SWTT'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef = hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef = handlerRef { RemoveEventHandler(handlerRef) }
    }
}
