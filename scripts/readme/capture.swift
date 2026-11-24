// The README's and the site's captures, with nothing on the screen (make.ts compiles and runs it):
//   capture <out.png> <url> <width> <height>   draws a page in an offscreen web view, in Retina pixels.
//   capture <out.mov> -- <command> [args...]   runs the command and records the first window it opens, at 60 fps in
//     Retina pixels, until it exits, the way the HUD skill checks motion: a display filter that includes only that
//     window, so a window under the desktop picture records. It prints each line the command writes with its time in
//     the recording: `<seconds>\t<line>`.
import AVFoundation
import ScreenCaptureKit
import WebKit

let args = CommandLine.arguments
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

// MARK: - A page

@MainActor final class Page: NSObject, WKNavigationDelegate {
    let view: WKWebView
    let window: NSWindow
    var loaded: CheckedContinuation<Void, Never>?
    init(width: Double, height: Double) {
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        view = WKWebView(frame: frame)
        // WebKit stops drawing a page its window hides, and under the desktop picture it hides all of it.
        view.perform(Selector(("_setWindowOcclusionDetectionEnabled:")), with: nil)  // nil: NO
        // Under the desktop picture: drawn at the screen's scale, and out of sight.
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.contentView = view
        super.init()
        view.navigationDelegate = self
        window.orderFrontRegardless()
    }
    func load(_ url: URL) async {
        await withCheckedContinuation {
            loaded = $0
            if url.isFileURL { view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) } else { view.load(URLRequest(url: url)) }
        }
        // Its fonts in. Under the desktop picture the page gets no animation frames to wait for; the snapshot draws it.
        _ = try? await view.callAsyncJavaScript("await document.fonts.ready", contentWorld: .page)
    }
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { loaded?.resume(); loaded = nil }
    }
}

if args.count == 5, let url = URL(string: args[2]), let width = Double(args[3]), let height = Double(args[4]) {
    _ = NSApplication.shared
    let page = Page(width: width, height: height)
    await page.load(url)
    let image = try await page.view.takeSnapshot(configuration: nil)
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cg.width == Int(width) * 2 else {
        fail("the snapshot is not at 2x: is the main display Retina?")
    }
    guard let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { fail("no png") }
    try png.write(to: URL(fileURLWithPath: args[1]))
    exit(0)
}

// MARK: - A window's recording

guard args.count > 3, let split = args.firstIndex(of: "--") else {
    fail("usage: capture <out.png> <url> <width> <height> | capture <out.mov> -- <command> [args...]")
}
let out = URL(fileURLWithPath: args[1])
try? FileManager.default.removeItem(at: out)

final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let queue = DispatchQueue(label: "frames")
    /// Host time of the first frame, to put the command's lines on the recording's clock.
    var first: Double?
    init(url: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        // Tagged as sRGB with BT.709's matrix, which ffmpeg reads back as it was written.
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.proRes4444, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pixels = buffer.imageBuffer else { return }
        let time = buffer.presentationTimeStamp
        if first == nil {
            first = time.seconds
            writer.startSession(atSourceTime: time)
        }
        if input.isReadyForMoreMediaData { adaptor.append(pixels, withPresentationTime: time) }
    }
}

// In a function, where `startCapture` and `stopCapture` are their async forms, not the ones with a handler.
func record(_ command: [String]) async throws -> Int32 {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: command[0])
    child.arguments = Array(command.dropFirst())
    let pipe = Pipe()
    child.standardOutput = pipe
    child.standardError = pipe
    try child.run()

    // The command's window: the first on screen or off that the child owns, once it has a size.
    var window: SCWindow?
    for _ in 0..<600 {
        if !child.isRunning { fail("\(command[0]) exited with no window: \(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))") }
        if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
           let found = content.windows.first(where: { $0.owningApplication?.processID == child.processIdentifier && $0.frame.width > 100 }) {
            window = found
            break
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    let displays = try await SCShareableContent.current.displays
    guard let window, let display = displays.first(where: { $0.frame.intersects(window.frame) }) ?? displays.first else {
        child.terminate()
        fail("no window from \(command[0])")
    }
    let scale = 2
    let config = SCStreamConfiguration()
    config.sourceRect = CGRect(x: window.frame.minX - display.frame.minX, y: window.frame.minY - display.frame.minY, width: window.frame.width, height: window.frame.height)
    config.width = Int(window.frame.width) * scale
    config.height = Int(window.frame.height) * scale
    config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.colorSpaceName = CGColorSpace.sRGB
    config.showsCursor = false
    config.queueDepth = 8
    let filter = SCContentFilter(display: display, including: [window])
    let recorder = try Recorder(url: out, width: config.width, height: config.height)
    let stream = SCStream(filter: filter, configuration: config, delegate: nil)
    try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: recorder.queue)
    try await stream.startCapture()

    // Each line the command prints, on the recording's clock.
    let lines = Task.detached {
        var buffer = Data()
        for try await byte in pipe.fileHandleForReading.bytes {
            if byte == 10 {
                let now = CMClockGetTime(CMClockGetHostTimeClock()).seconds
                let start = recorder.queue.sync { recorder.first } ?? now
                print(String(format: "%.3f\t%@", now - start, String(decoding: buffer, as: UTF8.self)))
                fflush(stdout)
                buffer.removeAll()
            } else {
                buffer.append(byte)
            }
        }
    }
    while child.isRunning { try await Task.sleep(for: .milliseconds(20)) }
    try await Task.sleep(for: .milliseconds(300))
    try await stream.stopCapture()
    _ = try? await lines.value
    await withCheckedContinuation { done in
        recorder.queue.async {
            recorder.input.markAsFinished()
            recorder.writer.finishWriting { done.resume() }
        }
    }
    return child.terminationStatus
}
exit(try await record(Array(args[(split + 1)...])))
