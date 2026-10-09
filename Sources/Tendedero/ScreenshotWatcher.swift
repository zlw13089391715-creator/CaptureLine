import Foundation

/// Watches saved captures; never records the screen itself.
@MainActor
final class ScreenshotWatcher {
    let folder: URL
    private let onlyTaggedScreenshots: Bool
    private var known = Set<String>()
    private var source: DispatchSourceFileSystemObject?
    private var pendingScan: DispatchWorkItem?
    private var timer: DispatchSourceTimer?
    private var running = false
    private let onNew: (URL) -> Bool
    private let onChange: () -> Void
    private let launchDate = Date()

    struct Signature: Equatable {
        let size: Int
        let modified: Date
        init?(_ url: URL) {
            guard let v = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  v.isRegularFile == true, let size = v.fileSize, let date = v.contentModificationDate else { return nil }
            self.size = size
            modified = date
        }
    }
    private struct Waiting {
        var signature: Signature
        var stableSince: Date
        var expired = false
        var task: Task<Void, Never>?
        var probeStarted: Date?
        let token = UUID()
    }
    private var waiting: [String: Waiting] = [:]

    static let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    init(folder: URL? = nil, onNew: @escaping (URL) -> Bool, onChange: @escaping () -> Void) {
        self.onNew = onNew
        self.onChange = onChange
        self.folder = (folder ?? Self.screenshotFolder()).standardizedFileURL.resolvingSymlinksInPath()
        onlyTaggedScreenshots = self.folder.path == Self.desktop.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func screenshotFolder() -> URL { captureFolder(key: "location-screenshot") }
    static func recordingFolder() -> URL { captureFolder(key: "location-video") }

    /// Separate keys on newer systems; older systems share `location`.
    static func captureFolder(key: String) -> URL {
        let domain = "com.apple.screencapture" as CFString
        CFPreferencesAppSynchronize(domain)
        return resolveFolder(specific: CFPreferencesCopyAppValue(key as CFString, domain) as? String,
                             shared: CFPreferencesCopyAppValue("location" as CFString, domain) as? String)
    }
    static func resolveFolder(specific: String?, shared: String?) -> URL {
        for raw in [specific, shared].compactMap({ $0 }) where !raw.isEmpty {
            let url = URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url.standardizedFileURL.resolvingSymlinksInPath()
            }
        }
        return desktop.standardizedFileURL.resolvingSymlinksInPath()
    }
    static func folders(includeDesktop: Bool) -> [URL] {
        var seen = Set<URL>()
        return ([screenshotFolder(), recordingFolder()] + (includeDesktop ? [desktop] : []))
            .map { URL(fileURLWithPath: $0.standardizedFileURL.resolvingSymlinksInPath().path, isDirectory: true) }
            .filter { seen.insert($0).inserted }
    }

    func start() {
        guard !running else { return }
        running = true
        known = Set(listing().filter { creationDate($0) < launchDate }.map(\.path))
        scan()
        let fd = open(folder.path, O_EVTONLY)
        if fd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
            src.setEventHandler { [weak self] in self?.scheduleScan() }
            src.setCancelHandler { close(fd) }
            src.resume()
            source = src
        } else { NSLog("Tendedero: cannot watch \(folder.path)") }
        // Directory events do not report writes inside an existing movie.
        // Poll metadata only; decoding is bounded and only happens for pending files.
        let poller = DispatchSource.makeTimerSource(queue: .main)
        poller.schedule(deadline: .now() + 1, repeating: 1)
        poller.setEventHandler { [weak self] in self?.scan() }
        poller.resume()
        timer = poller
    }
    func stop() {
        running = false
        pendingScan?.cancel()
        pendingScan = nil
        timer?.cancel()
        timer = nil
        source?.cancel()
        source = nil
        for entry in waiting.values { entry.task?.cancel() }
        waiting.removeAll()
    }
    private func scheduleScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scan() }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
    private func scan() {
        guard running else { return }
        let now = Date()
        let files = listing()
        let paths = Set(files.map(\.path))
        for path in Array(waiting.keys) where !paths.contains(path) {
            waiting.removeValue(forKey: path)?.task?.cancel()
        }
        for url in files {
            let path = url.path
            guard MediaKind.of(url) != nil, let signature = Signature(url) else { continue }
            if !known.contains(path) || waiting[path]?.signature != nil && waiting[path]?.signature != signature {
                waiting[path]?.task?.cancel()
                waiting[path] = Waiting(signature: signature, stableSince: now)
            }
            guard var entry = waiting[path], !entry.expired else { continue }
            let age = now.timeIntervalSince(entry.stableSince)
            if age >= 30 {
                entry.task?.cancel()
                entry.task = nil
                entry.expired = true
                waiting[path] = entry
                NSLog("Tendedero: capture did not become readable; leaving the file untouched")
                continue
            }
            if let started = entry.probeStarted, now.timeIntervalSince(started) > 10 {
                entry.task?.cancel()
                entry.task = nil
                entry.probeStarted = nil
                waiting[path] = entry
                continue
            }
            guard entry.task == nil, isCandidate(url) else { continue }
            if MediaKind.of(url) == .image {
                if onNew(url) { waiting[path] = nil }
            } else if signature.size > 0, age >= 2 {
                let token = entry.token
                entry.probeStarted = now
                entry.task = Task { [weak self] in
                    let ready = await VideoMedia.isPlayable(url)
                    guard !Task.isCancelled, let self, self.running,
                          self.waiting[path]?.token == token else { return }
                    self.waiting[path]?.task = nil
                    self.waiting[path]?.probeStarted = nil
                    // Writing may have resumed while AVFoundation was loading.
                    guard ready, Signature(url) == signature, self.isCandidate(url) else { return }
                    if self.onNew(url) { self.waiting[path] = nil }
                }
                waiting[path] = entry
            }
        }
        known = paths
        onChange()
    }
    private func listing() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        return urls.sorted { creationDate($0) < creationDate($1) }
    }
    private func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
    func isCandidate(_ url: URL) -> Bool {
        guard let kind = MediaKind.of(url) else { return false }
        if !onlyTaggedScreenshots { return true }
        if Self.isScreenCapture(url) { return true }
        return kind == .video && Self.isSystemRecordingName(url)
    }
    static func isScreenCapture(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            let name = "com.apple.metadata:kMDItemIsScreenCapture"
            let size = getxattr(path, name, nil, 0, 0, 0)
            guard size > 0, size < 4096 else { return false }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
            guard read == size,
                  let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? NSNumber else { return false }
            return value.boolValue
        }
    }
    /// Some recordings lack the screenshot attribute. Limit the fallback to
    /// system MOV names containing both a date and a time, not arbitrary videos.
    static func isSystemRecordingName(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "mov" else { return false }
        let name = url.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
        let pattern = #"^(?:Screen Recording\s+|(?:屏幕录制|录屏)\s*|Grabación de pantalla\s+)\d{4}[-年]\d{1,2}[-月]\d{1,2}日?(?:\s+(?:at\s+|a las\s+)?|\s*)(?:上午|下午)?\s*\d{1,2}[.：:]\d{2}[.：:]\d{2}(?:\s*[AP]M)?(?: \d+)?$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
