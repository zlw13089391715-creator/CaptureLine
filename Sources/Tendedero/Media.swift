import AppKit
import AVFoundation

enum MediaKind: Equatable {
    case image, video

    static func of(_ url: URL) -> MediaKind? {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp": return .image
        case "mov", "mp4", "m4v": return .video
        default: return nil
        }
    }
}

enum VideoMedia {
    /// Async property loading keeps large recordings off the UI thread.
    static func isPlayable(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        let timeout = DispatchWorkItem { asset.cancelLoading() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
        defer { timeout.cancel() }
        return await withTaskCancellationHandler {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let playable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration)
                return !Task.isCancelled && !tracks.isEmpty && playable
                    && duration.seconds.isFinite && duration.seconds > 0
            } catch { return false }
        } onCancel: {
            asset.cancelLoading()
        }
    }

    static func thumbnail(_ url: URL, maxPixels: Int = 480) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
        return await withTaskCancellationHandler {
            do {
                let result = try await generator.image(at: .zero)
                return Task.isCancelled ? nil : result.image
            } catch { return nil }
        } onCancel: {
            generator.cancelAllCGImageGeneration()
        }
    }

    @MainActor static func placeholder() -> NSImage {
        let size = NSSize(width: 160, height: 90)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.darkGray.setFill()
            rect.fill()
            NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)?
                .draw(in: NSRect(x: 56, y: 29, width: 48, height: 32))
            return true
        }
    }
}
