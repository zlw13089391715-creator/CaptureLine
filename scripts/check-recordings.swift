// Standalone integration checks; Command Line Tools suffice (no XCTest required).
// Run scripts/check-recordings.sh. Fixtures are synthetic frames, never screen captures.
import Foundation

func XCTAssertTrue(_ value: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if !value { fatalError("Assertion failed at \(file):\(line) \(message)") }
}
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(!value, file: file, line: line)
}
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(a == b, "\(a) != \(b) \(message)", file: file, line: line)
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(value == nil, file: file, line: line)
}
func XCTUnwrap<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let value else { fatalError("Unexpected nil at \(file):\(line)") }; return value
}
func XCTAssertLessThanOrEqual<T: Comparable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(a <= b, file: file, line: line)
}
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(a > b, file: file, line: line)
}
import AVFoundation
import AppKit

final class RecordingChecks {
    var cleanup: [() throws -> Void] = []
    func addTeardownBlock(_ block: @escaping () throws -> Void) { cleanup.append(block) }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func movie(at url: URL, type: AVFileType = .mov, rotated: Bool = false) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: type)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 90])
        if rotated { input.transform = CGAffineTransform(rotationAngle: .pi / 2) }
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                                         kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 90])
        writer.add(input)
        XCTAssertTrue(writer.startWriting(), writer.error?.localizedDescription ?? "")
        writer.startSession(atSourceTime: .zero)
        for n in 0..<10 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 10_000_000) }
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferCreate(nil, 160, 90, kCVPixelFormatType_32ARGB, nil, &buffer), kCVReturnSuccess)
            let pixels = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), 128, CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            XCTAssertTrue(adapter.append(pixels, withPresentationTime: CMTime(value: Int64(n), timescale: 10)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
    }

    @MainActor func testDesktopFilteringAndMetadata() throws {
        let watcher = ScreenshotWatcher(folder: ScreenshotWatcher.desktop, onNew: { _ in true }, onChange: {})
        for name in ["Screen Recording 2026-10-09 at 18.20.10.mov", "屏幕录制2026-10-09 18.20.10.mov",
                     "录屏2026-10-09 18.45.51.mov",
                     "Grabación de pantalla 2026-10-09 a las 18.20.10.mov"] {
            XCTAssertTrue(watcher.isCandidate(ScreenshotWatcher.desktop.appendingPathComponent(name)), name)
        }
        for name in ["holiday.mov", "Screen Recording.mov", "Screen Recording lesson.mp4", "photo.png"] {
            XCTAssertFalse(watcher.isCandidate(ScreenshotWatcher.desktop.appendingPathComponent(name)))
        }
        let url = try directory().appendingPathComponent("custom.mp4")
        try Data([1]).write(to: url)
        for value in [false, true] {
            let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
            let result = data.withUnsafeBytes {
                setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, data.count, 0, 0)
            }
            XCTAssertEqual(result, 0)
            XCTAssertEqual(watcher.isCandidate(url), value)
        }
    }

    @MainActor func testFoldersAndFormats() throws {
        let a = try directory(), b = try directory()
        XCTAssertEqual(ScreenshotWatcher.resolveFolder(specific: a.path, shared: b.path).path, a.path)
        XCTAssertEqual(ScreenshotWatcher.resolveFolder(specific: "/does/not/exist", shared: b.path).path, b.path)
        XCTAssertEqual(ScreenshotWatcher.resolveFolder(specific: nil, shared: nil).path, ScreenshotWatcher.desktop.path)
        XCTAssertEqual(Set(ScreenshotWatcher.folders(includeDesktop: true)).count,
                       ScreenshotWatcher.folders(includeDesktop: true).count)
        for ext in ["MOV", "mp4", "m4v"] { XCTAssertEqual(MediaKind.of(a.appendingPathComponent("clip.\(ext)")), .video) }
        let watcher = ScreenshotWatcher(folder: a, onNew: { _ in true }, onChange: {})
        XCTAssertTrue(watcher.isCandidate(a.appendingPathComponent("arbitrary.mp4")))
    }

    func testPlayableFormatsAndRotatedCover() async throws {
        let folder = try directory()
        for (ext, type) in [("mov", AVFileType.mov), ("mp4", .mp4), ("m4v", .m4v)] {
            let url = folder.appendingPathComponent("clip.\(ext)")
            try await movie(at: url, type: type, rotated: true)
            let playable = await VideoMedia.isPlayable(url)
            XCTAssertTrue(playable)
            let image = await VideoMedia.thumbnail(url, maxPixels: 48)
            let cover = try XCTUnwrap(image)
            XCTAssertLessThanOrEqual(max(cover.width, cover.height), 48)
            XCTAssertGreaterThan(cover.height, cover.width)
        }
        let broken = folder.appendingPathComponent("broken.mov")
        try Data([0, 1, 2]).write(to: broken)
        let playable = await VideoMedia.isPlayable(broken)
        XCTAssertFalse(playable)
    }

    @MainActor func testWatcherWaitsForFinishedFileAndDoesNotDuplicate() async throws {
        let folder = try directory()
        var received: [URL] = []
        let watcher = ScreenshotWatcher(folder: folder, onNew: { received.append($0); return true }, onChange: {})
        watcher.start()
        defer { watcher.stop() }
        let url = folder.appendingPathComponent("recording.mov")
        try Data([0, 1, 2]).write(to: url)
        try await Task.sleep(nanoseconds: 32_000_000_000)
        XCTAssertTrue(received.isEmpty)
        let finished = folder.appendingPathComponent(".finished.mov")
        try await movie(at: finished)
        let data = try Data(contentsOf: finished)
        try data.write(to: url) // No directory event required to retry an existing file.
        try await Task.sleep(nanoseconds: 5_000_000_000)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.lastPathComponent, url.lastPathComponent)
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: received[0].path, andPath: url.path))
        try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertEqual(received.count, 1)
    }

    @MainActor func testStopAndDeletionCancelPendingWork() async throws {
        let folder = try directory()
        var count = 0
        let watcher = ScreenshotWatcher(folder: folder, onNew: { _ in count += 1; return true }, onChange: {})
        watcher.start()
        let url = folder.appendingPathComponent("clip.mov")
        try await movie(at: url)
        watcher.stop()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertEqual(count, 0)
        watcher.start()
        try FileManager.default.removeItem(at: url)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        watcher.stop()
        XCTAssertEqual(count, 0)
    }

    @MainActor func testImageRegressionAndVideoClipboard() async throws {
        let folder = try directory()
        let imageURL = folder.appendingPathComponent("shot.png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 32,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: imageURL)
        let videoURL = folder.appendingPathComponent("clip.mov")
        try await movie(at: videoURL)
        let suite = "RecordingChecks.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "soundOff")
        let line = Line(defaults: defaults)
        try await Task.sleep(nanoseconds: 100_000_000)
        let imageID = try XCTUnwrap(line.hang(imageURL, quietly: true))
        let videoID = try XCTUnwrap(line.hang(videoURL, quietly: true))
        XCTAssertEqual(line.items.first?.kind, .image)
        XCTAssertEqual(line.items.first?.thumb.size, NSSize(width: 64, height: 32))
        let pb = NSPasteboard(name: NSPasteboard.Name(suite))
        defer { pb.releaseGlobally() }
        line.copy(imageID, pasteboard: pb)
        XCTAssertTrue(pb.data(forType: .png) != nil)
        line.copy(videoID, pasteboard: pb)
        XCTAssertNil(pb.data(forType: .png))
        XCTAssertTrue(pb.string(forType: .fileURL)?.hasSuffix("clip.mov") == true)
        line.clear()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertTrue(line.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path))
    }

    func testCaptureDestinationRoundtrip() throws {
        let folder = try directory()
        let suite = "CaptureDestinationChecks.\(UUID())"
        let domain = suite as CFString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let keys = ["location", "location-screenshot", "location-last", "target", "show-thumbnail"]
        func put(_ key: String, _ value: Any?) {
            CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
            CFPreferencesAppSynchronize(domain)
        }
        func read(_ key: String) -> Any? { CFPreferencesCopyAppValue(key as CFString, domain) }
        defer {
            for key in keys { put(key, nil) }
            defaults.removePersistentDomain(forName: suite)
        }
        for initialTarget in ["desktop", ""] {
            put("location", "/original/screenshots")
            put("location-screenshot", "/original/separate")
            put("location-last", "/original/custom")
            put("target", initialTarget.isEmpty ? nil : initialTarget)
            put("show-thumbnail", true)
            Inbox.apply(defaults: defaults, preferencesDomain: domain, destination: folder)
            XCTAssertEqual(read("target") as? String, "file")
            XCTAssertEqual(read("location") as? String, folder.path)
            XCTAssertEqual(read("location-last") as? String, folder.path)
            XCTAssertEqual(read("show-thumbnail") as? Bool, false)
            // Reapplying must retain the original backup rather than our own values.
            Inbox.apply(defaults: defaults, preferencesDomain: domain, destination: folder)
            Inbox.restore(defaults: defaults, preferencesDomain: domain, destination: folder)
            XCTAssertEqual(read("target") as? String, initialTarget.isEmpty ? nil : initialTarget)
            XCTAssertEqual(read("location") as? String, "/original/screenshots")
            XCTAssertEqual(read("location-screenshot") as? String, "/original/separate")
            XCTAssertEqual(read("location-last") as? String, "/original/custom")
            XCTAssertEqual(read("show-thumbnail") as? Bool, true)
        }
        // Upgrade a running pre-1.0.3 session whose backup lacks destination fields.
        put("location", folder.path)
        put("target", "desktop")
        put("location-last", nil)
        defaults.set(["location": "/original/screenshots", "thumbnail": true], forKey: "inboxSavedSettings")
        Inbox.apply(defaults: defaults, preferencesDomain: domain, destination: folder)
        XCTAssertEqual(read("target") as? String, "file")
        Inbox.restore(defaults: defaults, preferencesDomain: domain, destination: folder)
        XCTAssertEqual(read("target") as? String, "desktop")
        XCTAssertEqual(read("location") as? String, "/original/screenshots")
        XCTAssertNil(read("location-last"))
    }

    @MainActor func testRecordingCollectionMovesWithoutOverwriting() throws {
        let desktop = try directory(), inbox = try directory()
        let name = "录屏2026-10-09 19.10.10.mov"
        let source = desktop.appendingPathComponent(name)
        let existing = inbox.appendingPathComponent(name)
        let payload = Data([1, 2, 3, 4])
        try payload.write(to: source)
        try Data([9]).write(to: existing)
        let retained = try Inbox.collectRecording(source, enabled: false, desktop: desktop, destination: inbox)
        XCTAssertEqual(retained.lastPathComponent, name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let moved = try Inbox.collectRecording(source, enabled: true, desktop: desktop, destination: inbox)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: moved), payload)
        XCTAssertEqual(try Data(contentsOf: existing), Data([9]))
        XCTAssertEqual(moved.lastPathComponent, "录屏2026-10-09 19.10.10 2.mov")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: desktop.path).count, 0)
        let outside = try directory().appendingPathComponent(name)
        try payload.write(to: outside)
        _ = try Inbox.collectRecording(outside, enabled: true, desktop: desktop, destination: inbox)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        let ordinary = desktop.appendingPathComponent("holiday.mov")
        try payload.write(to: ordinary)
        _ = try Inbox.collectRecording(ordinary, enabled: true, desktop: desktop, destination: inbox)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordinary.path))
        // An invalid destination must not remove or truncate the source.
        try payload.write(to: source)
        do {
            _ = try Inbox.collectRecording(source, enabled: true, desktop: desktop, destination: existing)
            fatalError("Expected collection to fail")
        } catch {
            XCTAssertEqual(try Data(contentsOf: source), payload)
        }
    }

    @MainActor func testVideoRestoreAndRemovedCoverCannotReturn() async throws {
        let url = try directory().appendingPathComponent("clip.mov")
        try await movie(at: url)
        let suite = "RecordingTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "soundOff")
        defaults.set([url.path], forKey: "pegged")
        let line = Line(defaults: defaults)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(line.items.count, 1)
        XCTAssertEqual(line.items.first?.kind, .video)
        XCTAssertNil(line.hang(url))
        line.drop(try XCTUnwrap(line.items.first?.id), quietly: true)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertTrue(line.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(defaults.stringArray(forKey: "pegged"), [])
    }
}

@main struct CheckRecordings {
    @MainActor static func main() async throws {
        let checks = RecordingChecks()
        defer { checks.cleanup.forEach { try? $0() } }
        try checks.testCaptureDestinationRoundtrip()
        print("PASS: direct-save target, repeated apply, restore and older-session upgrade")
        if CommandLine.arguments.contains("--destination-only") { return }
        try checks.testDesktopFilteringAndMetadata()
        try checks.testFoldersAndFormats()
        print("PASS: desktop filtering, metadata and folders")
        try checks.testRecordingCollectionMovesWithoutOverwriting()
        print("PASS: inbox collection moves once, preserves collisions and failed sources")
        try await checks.testPlayableFormatsAndRotatedCover()
        print("PASS: MOV/MP4/M4V playback validation and rotated covers")
        try await checks.testWatcherWaitsForFinishedFileAndDoesNotDuplicate()
        print("PASS: invalid-file timeout, resumed writes and deduplication")
        try await checks.testStopAndDeletionCancelPendingWork()
        print("PASS: stop and deleted files cancel pending work")
        try await checks.testImageRegressionAndVideoClipboard()
        print("PASS: image thumbnails and image/video clipboard semantics")
        try await checks.testVideoRestoreAndRemovedCoverCannotReturn()
        print("PASS: video restoration and thumbnail cancellation")
    }
}
