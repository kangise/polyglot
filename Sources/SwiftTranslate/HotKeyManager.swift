import AppKit
import Carbon.HIToolbox

/// Registers one or more global hotkeys via the Carbon HotKey API.
/// Each hotkey has a string identifier so callers can dispatch per-key.
final class HotKeyManager {
    /// Called with the identifier of the triggered hotkey.
    var onTrigger: ((String) -> Void)?

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var idsByNumeric: [UInt32: String] = [:]
    private var handlerRef: EventHandlerRef?
    private var nextNumericID: UInt32 = 1

    private static var shared: HotKeyManager?

    func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        HotKeyManager.shared = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event = event else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            if let stringID = HotKeyManager.shared?.idsByNumeric[hkID.id] {
                HotKeyManager.shared?.onTrigger?(stringID)
            }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }

    /// Register a hotkey under a stable string id (e.g. "translate", "draft").
    @discardableResult
    func register(id: String, keyCode: UInt32, modifiers: UInt32) -> Bool {
        installHandlerIfNeeded()

        let numericID = nextNumericID
        nextNumericID += 1

        let signature: OSType = 0x53575454 // 'SWTT'
        let hotKeyID = EventHotKeyID(signature: signature, id: numericID)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref = ref else { return false }

        hotKeyRefs[numericID] = ref
        idsByNumeric[numericID] = id
        return true
    }

    deinit {
        for ref in hotKeyRefs.values { UnregisterEventHotKey(ref) }
        if let handlerRef = handlerRef { RemoveEventHandler(handlerRef) }
    }
}
