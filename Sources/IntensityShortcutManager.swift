import AppKit

final class IntensityShortcutManager {
    private var globalMonitor: Any?

    /// Callback invoked on main queue when Option+1/2/3/4 is pressed.
    var onIntensityChange: ((IntensityLevel) -> Void)?

    // Key codes for 1-4 on standard US keyboard layout.
    // These are hardware key codes, consistent across most standard keyboard layouts.
    private static let intensityKeyCodes: [UInt16: IntensityLevel] = [
        18: .l1,  // 1
        19: .l2,  // 2
        20: .l3,  // 3
        21: .l4   // 4
    ]

    func start() {
        stop()  // Idempotent — remove existing monitor before registering new one
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.option),
                  !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift),
                  !event.modifierFlags.contains(.control),
                  let level = Self.intensityKeyCodes[event.keyCode] else { return }
            DispatchQueue.main.async {
                self?.onIntensityChange?(level)
            }
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
