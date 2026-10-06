import AVFoundation
import AppKit
import Observation

/// Microphone and Accessibility, live. Accessibility has no callback, so it is polled: every second
/// while waiting for a grant, every ten seconds after, to notice a revoke.
@Observable
final class Permissions {
    private(set) var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    private(set) var accessibility = AXIsProcessTrusted()
    /// Accessibility is granted, yet macOS still refuses the event tap: only a relaunch helps.
    private(set) var needsRelaunch = false

    /// Called when Accessibility flips, to (re)create the event tap. Returns whether the tap is up.
    @ObservationIgnored var onAccessibility: ((Bool) -> Bool)?
    /// Called when the mic becomes usable, to prepare it.
    @ObservationIgnored var onMicrophone: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    var ready: Bool { microphone == .authorized && accessibility && !needsRelaunch }

    /// Accessibility is granted, yet the event tap was refused.
    func tapFailed() {
        needsRelaunch = true
    }

    func startPolling() {
        schedule()
    }

    func refresh() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        if mic != microphone {
            microphone = mic
            if mic == .authorized { onMicrophone?() }
            schedule()
        }
        let trusted = AXIsProcessTrusted()
        if trusted != accessibility || (trusted && needsRelaunch) {
            accessibility = trusted
            let tapUp = onAccessibility?(trusted) ?? trusted
            needsRelaunch = trusted && !tapUp
            schedule()
        }
    }

    func requestMicrophone() {
        if microphone == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.refresh() }
            }
        } else {
            Self.openPrivacy("Privacy_Microphone")
        }
    }

    /// Shows the system prompt once; after that, the pane in System Settings.
    func requestAccessibility() {
        let prompted = UserDefaults.standard.bool(forKey: "promptedAccessibility")
        if prompted {
            Self.openPrivacy("Privacy_Accessibility")
        } else {
            UserDefaults.standard.set(true, forKey: "promptedAccessibility")
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    static func openPrivacy(_ anchor: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = accessibility && microphone == .authorized ? 10 : 1
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in self.refresh() }
        }
        timer?.tolerance = interval / 2
    }
}
