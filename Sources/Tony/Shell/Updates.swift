import AppKit
import Observation
import Sparkle

/// In-app updates with Sparkle 2 from GitHub Releases. Checks at launch, every 4 hours (Info.plist),
/// and on wake, since the timer stops while the Mac sleeps. A check only finds the update: Sparkle keeps
/// a download until Tony quits, ignoring every newer release, so one made hours before the user restarts
/// installs an old version. Restart to Update checks again, then downloads and installs the latest in one go.
@Observable
final class Updates: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// The newest version on the feed, from the last check; nil while Tony is up to date.
    private(set) var available: String?
    /// Restart to Update was clicked: downloading and installing.
    private(set) var installing = false
    /// A dictation is running: installs wait until Tony is idle.
    @ObservationIgnored var isBusy: () -> Bool = { false }
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var relaunchWhenIdle: (() -> Void)?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    }

    func start() {
        // A development build (0.0.0) would replace itself with the latest release.
        guard Bundle.main.version != "0.0.0" else { return }
        controller.startUpdater()
        checkInBackground()
    }

    func checkInBackground() {
        guard controller.updater.canCheckForUpdates else { return }
        controller.updater.checkForUpdatesInBackground()
    }

    @objc func check() {
        controller.checkForUpdates(nil)
    }

    @objc func restartToUpdate() {
        installing = true
        checkInBackground()
    }

    /// Call when a dictation ends: a relaunch postponed for it goes ahead.
    func idle() {
        relaunchWhenIdle?()
        relaunchWhenIdle = nil
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        available = item.displayVersionString
        // Check for Updates shows Sparkle's own window, which downloads the latest when asked.
        guard installing || updateCheck == .updates else {
            throw NSError(domain: "Tony", code: 0, userInfo: [NSLocalizedDescriptionKey: "Waiting for Restart to Update."])
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        available = nil
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) -> Bool {
        immediateInstallationBlock()
        return true
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard isBusy() else { return false }
        relaunchWhenIdle = installHandler
        return true
    }

    /// The install failed (Tony relaunches when it works): Restart to Update comes back.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        installing = false
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Scheduled update alerts would steal focus from the app the user dictates into: Sparkle shows
    /// them in the background instead.
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
