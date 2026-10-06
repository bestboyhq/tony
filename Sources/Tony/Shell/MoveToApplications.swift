import AppKit

/// Sparkle cannot replace an app running from the disk image, from Downloads, or translocated by
/// Gatekeeper: on launch from one of those, offer to move Tony to Applications.
enum MoveToApplications {
    static func offerIfNeeded() {
        let bundle = Bundle.main.bundleURL
        let path = bundle.path
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
        guard path.contains("/AppTranslocation/") || path.hasPrefix("/Volumes/") || path.hasPrefix(downloads) else { return }

        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Move Tony to Applications?"
        alert.informativeText = "Tony can only update itself from the Applications folder."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let source = originalURL(of: bundle)
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(source.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            if !source.path.hasPrefix("/Volumes/") { try? FileManager.default.trashItem(at: source, resultingItemURL: nil) }
        } catch {
            let failed = NSAlert(error: error)
            failed.messageText = "Tony couldn't move itself. Drag it to Applications in Finder."
            failed.runModal()
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", destination.path]
        try? task.run()
        exit(0)
    }

    /// Where a translocated app really is (Security's SecTranslocateCreateOriginalPathForURL).
    private static func originalURL(of url: URL) -> URL {
        guard url.path.contains("/AppTranslocation/"),
              let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(handle, "SecTranslocateCreateOriginalPathForURL") else { return url }
        typealias Original = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        let original = unsafeBitCast(symbol, to: Original.self)
        return original(url as CFURL, nil)?.takeRetainedValue() as URL? ?? url
    }
}
