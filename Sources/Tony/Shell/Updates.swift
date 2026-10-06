import AppKit
import Observation
import Sparkle

/// In-app updates with Sparkle 2 from GitHub Releases. Checks at launch, every 4 hours (Info.plist),
/// and on wake, since the timer stops while the Mac sleeps. Downloads in the background and installs on
/// quit; nobody quits a menu bar app, so the menu offers Restart to Update.
@Observable
final class Updates: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// An update is downloaded and waits: the menu shows Restart to Update.
    private(set) var ready = false
    /// A dictation is running: installs wait until Tony is idle.
    @ObservationIgnored var isBusy: () -> Bool = { false }
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var installNow: (() -> Void)?
    @ObservationIgnored private var relaunchWhenIdle: (() -> Void)?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    }

    func start() {
        controller.startUpdater()
        checkInBackground()
    }

    func checkInBackground() {
        guard controller.updater.canCheckForUpdates else { return }
        controller.updater.checkForUpdatesInBackground()
    }

    func check() {
        controller.checkForUpdates(nil)
    }

    func restartToUpdate() {
        installNow?()
    }

    /// Call when a dictation ends: a relaunch postponed for it goes ahead.
    func idle() {
        relaunchWhenIdle?()
        relaunchWhenIdle = nil
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) -> Bool {
        installNow = immediateInstallationBlock
        ready = true
        return true
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard isBusy() else { return false }
        relaunchWhenIdle = installHandler
        return true
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Scheduled update alerts would steal focus from the app the user dictates into: Sparkle shows
    /// them in the background instead.
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
