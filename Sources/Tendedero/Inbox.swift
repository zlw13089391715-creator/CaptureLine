import Foundation

/// Inbox mode: Tendedero takes over where screenshots go.
///
/// It changes two macOS screenshot settings, the same ones in the Options
/// menu of Cmd+Shift+5: the floating thumbnail is turned off, so the file is
/// written at once instead of five seconds later, and the save location
/// becomes Tendedero's own folder, so the Desktop only gets what you keep.
///
/// The previous values are saved first and put back when the mode is turned
/// off or the app quits, so macOS is never left pointing at a folder nobody
/// is watching.
enum Inbox {
    private static let domain = "com.apple.screencapture" as CFString
    /// macOS 26 and earlier read "location". macOS 27 reads
    /// "location-screenshot" and ignores the old key, so both are written.
    private static let locationKey = "location" as CFString
    private static let screenshotLocationKey = "location-screenshot" as CFString
    private static let targetKey = "target" as CFString
    private static let lastLocationKey = "location-last" as CFString
    private static let thumbnailKey = "show-thumbnail" as CFString

    private static let enabledKey = "inboxEnabled"
    private static let offeredKey = "inboxOffered"
    private static let savedKey = "inboxSavedSettings"

    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CaptureLine/Screenshots", isDirectory: true)
    }()

    /// The user's choice, kept across launches.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Whether we already asked, so the offer appears only once.
    static var wasOffered: Bool {
        get { UserDefaults.standard.bool(forKey: offeredKey) }
        set { UserDefaults.standard.set(newValue, forKey: offeredKey) }
    }

    /// Whether macOS is currently sending screenshots to our folder.
    static var isApplied: Bool { isApplied(domain: domain, folder: folder) }
    private static func isApplied(domain: CFString, folder: URL) -> Bool {
        guard let current = CFPreferencesCopyAppValue(locationKey, domain) as? String else { return false }
        return URL(fileURLWithPath: (current as NSString).expandingTildeInPath).standardizedFileURL.path
            == folder.standardizedFileURL.path
    }

    static func apply(defaults: UserDefaults = .standard, preferencesDomain: CFString = domain, destination: URL = folder) {
        let domain = preferencesDomain
        let folder = destination
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Never save our own values as the "previous" ones, for example after
        // a crash left them applied.
        if !isApplied(domain: domain, folder: folder) {
            let saved: [String: Any] = [
                "location": CFPreferencesCopyAppValue(locationKey, domain) as? String ?? NSNull(),
                "locationScreenshot": CFPreferencesCopyAppValue(screenshotLocationKey, domain) as? String ?? NSNull(),
                "thumbnail": CFPreferencesCopyAppValue(thumbnailKey, domain) as? Bool ?? NSNull(),
            ]
            defaults.set(saved.compactMapValues { $0 is NSNull ? nil : $0 }, forKey: savedKey)
        }
        // The system toolbar defaults to Desktop unless its target is `file`.
        // Back up these fields independently when upgrading an older inbox session.
        var saved = defaults.dictionary(forKey: savedKey) ?? [:]
        if saved["recordingDestinationSaved"] as? Bool != true {
            saved["target"] = CFPreferencesCopyAppValue(targetKey, domain) as? String
            saved["locationLast"] = CFPreferencesCopyAppValue(lastLocationKey, domain) as? String
            saved["recordingDestinationSaved"] = true
            defaults.set(saved, forKey: savedKey)
        }
        set(targetKey, "file", domain: domain)
        set(lastLocationKey, folder.path, domain: domain)
        set(locationKey, folder.path, domain: domain)
        set(screenshotLocationKey, folder.path, domain: domain)
        set(thumbnailKey, false, domain: domain)
    }

    static func restore(defaults: UserDefaults = .standard, preferencesDomain: CFString = domain, destination: URL = folder) {
        let domain = preferencesDomain
        let folder = destination
        guard isApplied(domain: domain, folder: folder) else { return }
        let saved = defaults.dictionary(forKey: savedKey) ?? [:]
        set(locationKey, saved["location"], domain: domain)
        set(screenshotLocationKey, saved["locationScreenshot"], domain: domain)
        set(thumbnailKey, saved["thumbnail"], domain: domain)
        if saved["recordingDestinationSaved"] as? Bool == true {
            if CFPreferencesCopyAppValue(targetKey, domain) as? String == "file" {
                set(targetKey, saved["target"], domain: domain)
            }
            if let last = CFPreferencesCopyAppValue(lastLocationKey, domain) as? String,
               URL(fileURLWithPath: (last as NSString).expandingTildeInPath).standardizedFileURL.path == folder.standardizedFileURL.path {
                set(lastLocationKey, saved["locationLast"], domain: domain)
            }
        }
        defaults.removeObject(forKey: savedKey)
    }

    /// Move completed desktop recordings into the inbox; never copy or overwrite.
    @MainActor static func collectRecording(_ url: URL) throws -> URL {
        try collectRecording(url, enabled: isEnabled,
            desktop: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            destination: folder)
    }

    @MainActor static func collectRecording(_ url: URL, enabled: Bool,
                                            desktop: URL, destination: URL) throws -> URL {
        let source = url.standardizedFileURL.resolvingSymlinksInPath()
        guard enabled, MediaKind.of(source) == .video,
              source.deletingLastPathComponent().path == desktop.standardizedFileURL.resolvingSymlinksInPath().path,
              ScreenshotWatcher.isScreenCapture(source) || ScreenshotWatcher.isSystemRecordingName(source) else {
            return source
        }
        let targetFolder = destination.standardizedFileURL.resolvingSymlinksInPath()
        if source.deletingLastPathComponent().path == targetFolder.path { return source }
        let fm = FileManager.default
        try fm.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        var target = targetFolder.appendingPathComponent(source.lastPathComponent)
        let stem = source.deletingPathExtension().lastPathComponent
        var n = 2
        while true {
            do {
                try fm.moveItem(at: source, to: target)
                return target
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain,
                      error.code == CocoaError.fileWriteFileExists.rawValue else { throw error }
                target = targetFolder.appendingPathComponent("\(stem) \(n)").appendingPathExtension(source.pathExtension)
                n += 1
            }
        }
    }

    /// Writes through cfprefsd, so the screenshot service sees it at once.
    /// A nil value removes the key and returns it to the macOS default.
    private static func set(_ key: CFString, _ value: Any?, domain: CFString) {
        CFPreferencesSetAppValue(key, value as CFPropertyList?, domain)
        CFPreferencesAppSynchronize(domain)
    }
}
