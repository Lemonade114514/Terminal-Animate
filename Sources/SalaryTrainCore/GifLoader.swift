import Foundation
import ImageIO
import CoreGraphics

public struct GifFrame {
    public let image: CGImage
    public let duration: Double
    public init(image: CGImage, duration: Double) { self.image = image; self.duration = duration }
}

public enum GifLoader {
    public static func loadGif(at url: URL) -> [GifFrame] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            fputs("GIF load failed: \(url.path)\n", stderr)
            exit(1)
        }
        let count = CGImageSourceGetCount(source)
        var frames: [GifFrame] = []
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let duration = frameDuration(at: i, source: source)
            frames.append(GifFrame(image: cg, duration: max(duration, 0.1)))
        }
        if frames.isEmpty {
            fputs("No frames in GIF: \(url.path)\n", stderr)
            exit(1)
        }
        return frames
    }

    public static func trim(_ frames: [GifFrame]) -> [GifFrame] {
        var unionBox: CGRect? = nil
        for frame in frames {
            let box = alphaBounds(frame.image)
            guard let b = box else { continue }
            unionBox = unionBox == nil ? b : unionBox!.union(b)
        }
        guard let crop = unionBox else { return frames }
        let first = frames[0].image
        if crop.origin == .zero && crop.size.width == CGFloat(first.width) && crop.size.height == CGFloat(first.height) {
            return frames
        }
        return frames.map { GifFrame(image: cropImage($0.image, to: crop), duration: $0.duration) }
    }

    /// 在相邻帧之间插入插值帧，提升动画流畅度。
    /// - framesPerOriginal: 每对相邻帧之间插入的插值帧数（例如 2 表示插入 2 帧，总帧数约为原始的 3 倍）
    public static func interpolateFrames(_ frames: [GifFrame], framesPerOriginal: Int = 2) -> [GifFrame] {
        guard frames.count >= 2 else { return frames }
        var result: [GifFrame] = []
        let cs = CGColorSpaceCreateDeviceRGB()
        for i in 0..<frames.count {
            result.append(frames[i])
            let next = frames[(i + 1) % frames.count]
            for k in 1...framesPerOriginal {
                let t = Double(k) / Double(framesPerOriginal + 1)
                if let blended = blendImages(frames[i].image, next.image, ratio: t, colorSpace: cs) {
                    let dur = frames[i].duration / Double(framesPerOriginal + 1)
                    result.append(GifFrame(image: blended, duration: dur))
                }
            }
        }
        return result
    }

    private static func blendImages(_ imgA: CGImage, _ imgB: CGImage, ratio t: Double, colorSpace cs: CGColorSpace) -> CGImage? {
        let w = max(imgA.width, imgB.width)
        let h = max(imgA.height, imgB.height)
        guard w > 0, h > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.clear(rect)
        ctx.setAlpha(CGFloat(1.0 - t))
        ctx.draw(imgA, in: rect)
        ctx.setAlpha(CGFloat(t))
        ctx.setBlendMode(.normal)
        ctx.draw(imgB, in: rect)
        return ctx.makeImage()
    }

    private static func frameDuration(at index: Int, source: CGImageSource) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
        if let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            if let ms = gif[kCGImagePropertyGIFDelayTime] as? Double {
                return ms / 1000.0
            }
            if let ms = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double {
                return ms / 1000.0
            }
        }
        return 0.1
    }

    private static func alphaBounds(_ image: CGImage) -> CGRect? {
        let w = image.width
        let h = image.height
        guard w > 0 && h > 0 else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: w * h * bytesPerPixel)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let alpha = pixels[(y * w + x) * bytesPerPixel + 3]
                if alpha >= 200 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        if maxX < 0 { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static func cropImage(_ image: CGImage, to rect: CGRect) -> CGImage {
        let r = CGRect(
            x: rect.origin.x,
            y: CGFloat(image.height) - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        return image.cropping(to: r) ?? image
    }
}
