import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Uses the Carbon hotkey API, which needs no Accessibility permission.
@MainActor
final class HotKey {
    private static var action: (@MainActor () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Defaults to Option-Space.
    init(keyCode: Int = kVK_Space, modifiers: Int = optionKey, action: @escaping @MainActor () -> Void) {
        Self.action = action

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &pressed, nil, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x5345_4755), id: 1)  // "SEGU"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
