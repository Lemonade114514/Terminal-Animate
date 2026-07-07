import Foundation
import CoreGraphics
import ImageIO

public struct RGB: Equatable {
    public let r: Int, g: Int, b: Int
    public init(r: Int, g: Int, b: Int) { self.r = r; self.g = g; self.b = b }
}

public struct RenderedFrame {
    public let lines: [String]
    public let duration: Double
    public init(lines: [String], duration: Double) { self.lines = lines; self.duration = duration }
}

/// 月薪喵渲染模式。
public enum RenderMode {
    case filled     // 全彩填充
    case outline    // Sobel 边缘线稿（原色）
    case bw         // 取模黑白：白色剪影 on 黑底
    case bwDither   // Floyd-Steinberg 抖动黑白
    case bwEdge     // 黑底白线勾边：Sobel 边缘统一画白，内部留空
}

/// 月薪喵动画预设参数包。每条 static let 是一份预设。
/// 预设参数表：
///   outline    Sobel 边缘线稿, edgeThreshold 60
///   filled     全彩填充
///   bw         取模黑白白色剪影, bwThreshold 128
///   bwDither   Floyd-Steinberg 抖动黑白, bwThreshold 128
///   bwEdge     黑底白线勾边（边缘统一白，内部留空）, edgeThreshold 200
public struct RenderParams {
    public var mode: RenderMode
    public var edgeThreshold: Int
    public var bwThreshold: Int
    public var stripeThreshold: Int  // bwEdge: 亮度差低于此值的边缘被抑制（去花纹）

    public init(mode: RenderMode, edgeThreshold: Int, bwThreshold: Int, stripeThreshold: Int = 30) {
        self.mode = mode; self.edgeThreshold = edgeThreshold; self.bwThreshold = bwThreshold; self.stripeThreshold = stripeThreshold
    }

    public static let outline   = RenderParams(mode: .outline,   edgeThreshold: 60,  bwThreshold: 0)
    public static let filled    = RenderParams(mode: .filled,    edgeThreshold: 0,   bwThreshold: 0)
    public static let bw        = RenderParams(mode: .bw,        edgeThreshold: 0,   bwThreshold: 128)
    public static let bwDither  = RenderParams(mode: .bwDither,  edgeThreshold: 0,   bwThreshold: 128)
    public static let bwEdge    = RenderParams(mode: .bwEdge,    edgeThreshold: 200, bwThreshold: 0, stripeThreshold: 100)
}

public enum FrameRenderer {
    public static let reset = "\u{1b}[0m"
    public static let defaultFG = "\u{1b}[39m"
    public static let defaultBG = "\u{1b}[49m"
    public static let blackBG = "\u{1b}[48;2;0;0;0m"
    public static let alphaThreshold: UInt8 = 200

    public static func fitSize(source: (Int, Int), terminal: TerminalSize, reservedRows: Int = 0, verticalPixelsPerRow: Int = 2) -> (Int, Int) {
        let availableW = max(1, terminal.columns)
        let availablePixelH = max(1, (terminal.rows - reservedRows) * verticalPixelsPerRow)
        let scaleW = Double(availableW) / Double(max(1, source.0))
        let scaleH = Double(availablePixelH) / Double(max(1, source.1))
        let scale = min(scaleW, scaleH)
        return (max(1, Int(Double(source.0) * scale)), max(1, Int(Double(source.1) * scale)))
    }

    public static func resize(_ image: CGImage, to size: (Int, Int)) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size.0,
            height: size.1,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size.0, height: size.1))
        return ctx.makeImage() ?? image
    }

    public static func render(_ image: CGImage) -> [String] {
        render(image, params: .filled)
    }

    public static func render(_ image: CGImage, params: RenderParams) -> [String] {
        let result = renderPixels(image, params: params)
        if params.mode == .bwEdge {
            return encodeSlashLines(pixels: result.pixels, width: result.width, height: result.height)
        }
        return encodeLines(pixels: result.pixels, width: result.width, height: result.height)
    }

    /// 像素处理 seam：解码 CGImage → RGBA，按 params 模式变换（Sobel/bw/dither/edge）。
    /// 返回处理后的 straight-alpha、top-down RGBA 像素缓冲。
    public static func renderPixels(_ image: CGImage, params: RenderParams) -> (pixels: [UInt8], width: Int, height: Int) {
        let w = image.width
        let h = image.height
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
        ) else { return (pixels, w, h) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        switch params.mode {
        case .outline:
            applySobelEdges(pixels: &pixels, width: w, height: h, threshold: params.edgeThreshold)
        case .bw:
            applyBlackWhite(pixels: &pixels, width: w, height: h, threshold: params.bwThreshold)
        case .bwDither:
            applyBlackWhiteDither(pixels: &pixels, width: w, height: h, threshold: params.bwThreshold)
        case .bwEdge:
            let eyeMask = detectEyeMask(pixels: pixels, width: w, height: h)
            let lumMap = computeLuminanceMap(pixels: pixels, width: w, height: h)
            binarizeAlpha(pixels: &pixels, width: w, height: h, alphaThreshold: 128)
            applySobelEdges(pixels: &pixels, width: w, height: h, threshold: params.edgeThreshold, storeDirection: true)
            filterStripeEdges(pixels: &pixels, width: w, height: h, lumMap: lumMap, stripeThreshold: params.stripeThreshold)
            fillEyes(pixels: &pixels, width: w, height: h, eyeMask: eyeMask)
        case .filled:
            break
        }
        return (pixels, w, h)
    }

    /// 编码 seam：RGBA 像素缓冲 → ANSI 半块字符串行数组。
    public static func encodeLines(pixels: [UInt8], width: Int, height: Int) -> [String] {
        let w = width
        let h = height
        let bytesPerPixel = 4

        func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
            if x < 0 || x >= w || y < 0 || y >= h {
                return (0, 0, 0, 0)
            }
            let i = (y * w + x) * bytesPerPixel
            return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
        }

        var lines: [String] = []
        var y = 0
        while y < h {
            var parts: [String] = []
            var lastFG: RGB? = nil
            var lastBG: RGB? = nil
            var bgActive = false

            for x in 0..<w {
                let top = pixel(x, y)
                let bottom = pixel(x, y + 1)
                let topVis = top.3 >= alphaThreshold
                let bottomVis = bottom.3 >= alphaThreshold

                var char = " "
                var fg: RGB? = nil
                var bg: RGB? = nil

                if topVis && bottomVis {
                    fg = RGB(r: Int(top.0), g: Int(top.1), b: Int(top.2))
                    bg = RGB(r: Int(bottom.0), g: Int(bottom.1), b: Int(bottom.2))
                    char = "\u{2580}"
                } else if topVis {
                    fg = RGB(r: Int(top.0), g: Int(top.1), b: Int(top.2))
                    bg = RGB(r: 0, g: 0, b: 0)
                    char = "\u{2580}"
                } else if bottomVis {
                    fg = RGB(r: Int(bottom.0), g: Int(bottom.1), b: Int(bottom.2))
                    bg = RGB(r: 0, g: 0, b: 0)
                    char = "\u{2584}"
                } else {
                    fg = nil
                    bg = RGB(r: 0, g: 0, b: 0)
                    char = " "
                }

                if fg != lastFG {
                    if let c = fg {
                        parts.append("\u{1b}[38;2;\(c.r);\(c.g);\(c.b)m")
                    } else {
                        parts.append(defaultFG)
                    }
                    lastFG = fg
                }
                if bg != lastBG {
                    if let c = bg {
                        parts.append("\u{1b}[48;2;\(c.r);\(c.g);\(c.b)m")
                        bgActive = true
                    } else {
                        parts.append(defaultBG)
                        bgActive = false
                    }
                    lastBG = bg
                }
                if char == " " && bgActive {
                    parts.append(" ")
                } else {
                    parts.append(char)
                }
            }
            parts.append(reset)
            lines.append(parts.joined())
            y += 2
        }
        return lines
    }

    /// 斜线编码 seam：2 像素 = 1 终端格（和半块模式一致）。
    /// 按 R 通道存储的方向码画 /\|- 字符。
    /// 方向码：0=|(竖边), 1=/(斜边), 2=-(横边), 3=\(反斜边)。
    /// R=255 表示实心填充像素（眼睛），画半块实心字符（▀/▄/█）。
    /// 对每对像素行 (y, y+1)，检查两行：
    /// - 任一行有眼睛填充 → 画实心块
    /// - 否则任一行有边缘 → 用该像素方向码画斜线；都有 → 取顶部
    public static func encodeSlashLines(pixels: [UInt8], width: Int, height: Int) -> [String] {
        let w = width
        let h = height
        let bpp = 4
        let slashChars = ["|", "/", "-", "\\"]
        let whiteFG = "\u{1b}[38;2;255;255;255m"
        var lines: [String] = []
        var y = 0
        while y < h {
            var parts: [String] = [blackBG]
            for x in 0..<w {
                let topI = (y * w + x) * bpp
                let topA = Int(pixels[topI + 3])
                let topR = Int(pixels[topI])
                let botI = y + 1 < h ? ((y + 1) * w + x) * bpp : topI
                let botA = y + 1 < h ? Int(pixels[botI + 3]) : 0
                let botR = y + 1 < h ? Int(pixels[botI]) : 0

                let topEye = topA >= 200 && topR == 255
                let botEye = botA >= 200 && botR == 255
                let topEdge = topA >= 200 && topR < 4
                let botEdge = botA >= 200 && botR < 4

                var ch = " "
                if topEye || botEye {
                    // 眼睛实心块：上下都填充→█，仅上→▀，仅下→▄
                    if topEye && botEye {
                        ch = "\u{2588}" // █
                    } else if topEye {
                        ch = "\u{2580}" // ▀
                    } else {
                        ch = "\u{2584}" // ▄
                    }
                    parts.append(whiteFG)
                } else if topEdge || botEdge {
                    // 斜线边缘
                    let dirCode: Int
                    if topEdge {
                        dirCode = Int(pixels[topI])
                    } else {
                        dirCode = Int(pixels[botI])
                    }
                    ch = slashChars[dirCode]
                    parts.append(whiteFG)
                }
                parts.append(ch)
            }
            parts.append(reset)
            lines.append(parts.joined())
            y += 2
        }
        return lines
    }
    /// Non-edge pixels become transparent (alpha=0); edge pixels keep original RGB, alpha=255.
    /// Luminance includes alpha so silhouette boundaries against the transparent
    /// background are detected as edges too.
    private static func applySobelEdges(pixels: inout [UInt8], width: Int, height: Int, threshold: Int, storeDirection: Bool = false) {
        let bpp = 4
        // Build a luminance map (alpha-weighted so transparency gradients count).
        var lum = [Int](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])
                let yl = (a * (299 * r + 587 * g + 114 * b)) / 255 / 1000
                lum[y * width + x] = yl
            }
        }

        // Sobel gradient magnitude + direction for every pixel.
        var mag = [Int](repeating: 0, count: width * height)
        var dir = [UInt8](repeating: 0, count: width * height)  // 0=0°, 1=45°, 2=90°, 3=135°
        for y in 0..<height {
            for x in 0..<width {
                let xl = x == 0 ? x : x - 1
                let xr = x == width - 1 ? x : x + 1
                let yt = y == 0 ? y : y - 1
                let yb = y == height - 1 ? y : y + 1

                let tl = lum[yt * width + xl], tc = lum[yt * width + x], tr = lum[yt * width + xr]
                let ml = lum[y  * width + xl],                       mr = lum[y  * width + xr]
                let bl = lum[yb * width + xl], bc = lum[yb * width + x], br = lum[yb * width + xr]

                let gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                let gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                let m = abs(gx) + abs(gy)
                mag[y * width + x] = m

                // Quantize gradient direction to 4 bins (compare against gradient angle,
                // i.e. perpendicular to edge). Use gx/gy ratio to avoid atan2.
                let ax = abs(gx), ay = abs(gy)
                if ax >= 3 * ay { dir[y * width + x] = 0 }       // ~0°  (horizontal edge, gradient horizontal)
                else if ay >= 3 * ax { dir[y * width + x] = 2 }  // ~90° (vertical edge, gradient vertical)
                else if gx * gy >= 0 { dir[y * width + x] = 1 }  // ~45° (gx,gy same sign)
                else { dir[y * width + x] = 3 }                   // ~135° (gx,gy opposite sign)
            }
        }

        // Non-Maximum Suppression: keep pixel only if its mag is the local max
        // along the gradient direction. Suppress (set mag=0) otherwise.
        var edge = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let m = mag[idx]
                if m < threshold { continue }
                let d = dir[idx]
                // Neighbours along gradient direction.
                let n1: Int, n2: Int
                switch d {
                case 0:  // horizontal gradient → compare (x-1, y) and (x+1, y)
                    n1 = x > 0 ? mag[y * width + (x - 1)] : 0
                    n2 = x < width - 1 ? mag[y * width + (x + 1)] : 0
                case 2:  // vertical gradient → compare (x, y-1) and (x, y+1)
                    n1 = y > 0 ? mag[(y - 1) * width + x] : 0
                    n2 = y < height - 1 ? mag[(y + 1) * width + x] : 0
                case 1:  // 45° gradient → compare (x-1, y-1) and (x+1, y+1)
                    n1 = (x > 0 && y > 0) ? mag[(y - 1) * width + (x - 1)] : 0
                    n2 = (x < width - 1 && y < height - 1) ? mag[(y + 1) * width + (x + 1)] : 0
                default: // 135° gradient → compare (x+1, y-1) and (x-1, y+1)
                    n1 = (x < width - 1 && y > 0) ? mag[(y - 1) * width + (x + 1)] : 0
                    n2 = (x > 0 && y < height - 1) ? mag[(y + 1) * width + (x - 1)] : 0
                }
                // Keep pixel only if strictly greater than BOTH neighbours.
                // Hard step edges produce a 2px-wide equal-magnitude band; strict
                // comparison would suppress both. Tie-break: when equal to a
                // neighbour on one side and strictly greater on the other, keep
                // only the LEFT/TOP pixel of the tie (deterministic) → 1px edge.
                if m > n1 && m > n2 {
                    edge[idx] = 1
                } else if m > n1 && m == n2 {
                    // strictly greater than left, equal to right → we are the left winner
                    edge[idx] = 1
                }
                // m == n1 (equal to left) → suppress: the pixel to our left wins.
                // m == n1 == n2 → suppress (flat, no edge).
            }
        }

        // Zero out non-edge pixels; make edge pixels opaque.
        // storeDirection: edge pixel R = dir code (0-3), G=0, B=0 (for slash-line encoder).
        // !storeDirection: edge pixel keeps original RGB (for outline mode).
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                if edge[y * width + x] == 1 {
                    if storeDirection {
                        pixels[i] = dir[y * width + x]   // 0=|, 1=/, 2=-, 3=\
                        pixels[i + 1] = 0
                        pixels[i + 2] = 0
                    }
                    pixels[i + 3] = 255
                } else {
                    pixels[i] = 0
                    pixels[i + 1] = 0
                    pixels[i + 2] = 0
                    pixels[i + 3] = 0
                }
            }
        }
    }

    /// 二值化 alpha：alpha >= threshold → 不透明（alpha=255，un-premultiply RGB）；
    /// alpha < threshold → 全透明（RGB=0, alpha=0）。
    /// 消除抗锯齿半透明像素，让 Sobel 只检测硬边缘，去掉浅灰杂色块。
    private static func binarizeAlpha(pixels: inout [UInt8], width: Int, height: Int, alphaThreshold: Int) {
        let bpp = 4
        for i in stride(from: 0, to: width * height * bpp, by: bpp) {
            let a = Int(pixels[i + 3])
            if a >= alphaThreshold {
                // un-premultiply: restore original RGB from premultiplied values.
                if a > 0 {
                    pixels[i]     = UInt8(min(255, Int(pixels[i])     * 255 / a))
                    pixels[i + 1] = UInt8(min(255, Int(pixels[i + 1]) * 255 / a))
                    pixels[i + 2] = UInt8(min(255, Int(pixels[i + 2]) * 255 / a))
                }
                pixels[i + 3] = 255
            } else {
                pixels[i] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = 0
            }
        }
    }

    /// 取模黑白：亮度 >= threshold 的像素画白（不透明），其余透明。
    /// 透明像素视为黑（Y=0），保证外轮廓被切掉，得到干净的白色剪影 on 黑底。
    private static func applyBlackWhite(pixels: inout [UInt8], width: Int, height: Int, threshold: Int) {
        let bpp = 4
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                let a = Int(pixels[i + 3])
                let yl = a * (299 * Int(pixels[i]) + 587 * Int(pixels[i + 1]) + 114 * Int(pixels[i + 2])) / 255 / 1000
                if yl >= threshold {
                    pixels[i] = 255
                    pixels[i + 1] = 255
                    pixels[i + 2] = 255
                    pixels[i + 3] = 255
                } else {
                    pixels[i] = 0
                    pixels[i + 1] = 0
                    pixels[i + 2] = 0
                    pixels[i + 3] = 0
                }
            }
        }
    }

    /// Floyd-Steinberg 抖动黑白：把灰度误差扩散到邻居，保留阴影层次。
    /// 结果仍是 0/255 二值，但有疏密点阵渐变，像 OLED 取模。
    private static func applyBlackWhiteDither(pixels: inout [UInt8], width: Int, height: Int, threshold: Int) {
        let bpp = 4
        // 灰度误差缓存（带 alpha 加权，透明像素 Y=0）。
        var errors = [Double](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                let a = Double(pixels[i + 3]) / 255.0
                let yl = a * (0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2]))
                errors[y * width + x] = yl
            }
        }

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let old = errors[idx]
                // 二值化：>= threshold 为白（255），否则黑（0）。
                let newVal: Double = old >= Double(threshold) ? 255.0 : 0.0
                errors[idx] = newVal
                let err = old - newVal
                // Floyd-Steinberg 误差扩散。
                func push(_ nx: Int, _ ny: Int, _ factor: Double) {
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { return }
                    errors[ny * width + nx] += err * factor
                }
                push(x + 1, y,     7.0 / 16.0)
                push(x - 1, y + 1, 3.0 / 16.0)
                push(x,     y + 1, 5.0 / 16.0)
                push(x + 1, y + 1, 1.0 / 16.0)
            }
        }

        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                if errors[y * width + x] >= 255.0 {
                    pixels[i] = 255
                    pixels[i + 1] = 255
                    pixels[i + 2] = 255
                    pixels[i + 3] = 255
                } else {
                    pixels[i] = 0
                    pixels[i + 1] = 0
                    pixels[i + 2] = 0
                    pixels[i + 3] = 0
                }
            }
        }
    }

    // MARK: - bwEdge: 眼睛检测、花纹过滤、眼睛填充

    /// 计算原始像素的亮度图（alpha 加权），用于花纹过滤。
    private static func computeLuminanceMap(pixels: [UInt8], width: Int, height: Int) -> [Int] {
        let bpp = 4
        var lum = [Int](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])
                lum[y * width + x] = (a * (299 * r + 587 * g + 114 * b)) / 255 / 1000
            }
        }
        return lum
    }

    /// 检测眼睛像素（蓝色：B > R+30 && B > G+10 && alpha > 128）。
    /// 返回与像素缓冲等长的 Bool 数组，true = 该像素属于眼睛区域。
    private static func detectEyeMask(pixels: [UInt8], width: Int, height: Int) -> [Bool] {
        let bpp = 4
        var mask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])
                if a > 128 && b > r + 30 && b > g + 10 {
                    mask[y * width + x] = true
                }
            }
        }
        return mask
    }

    /// 抑制亮度差低于 stripeThreshold 且两侧都是不透明像素的边缘（色块边界/花纹）。
    /// 轮廓边缘（一侧透明）和眼睛边缘（亮度差大）保留。
    private static func filterStripeEdges(pixels: inout [UInt8], width: Int, height: Int, lumMap: [Int], stripeThreshold: Int) {
        let bpp = 4
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bpp
                guard pixels[i + 3] >= 200 else { continue } // 只检查边缘像素
                let dirCode = Int(pixels[i])
                // 根据方向码确定采样偏移 (dx, dy)
                let (dx, dy): (Int, Int)
                switch dirCode {
                case 0:  dx = 1; dy = 0   // 水平梯度 → 比较左右
                case 2:  dx = 0; dy = 1   // 竖直梯度 → 比较上下
                case 1:  dx = 1; dy = 1   // 45° → 比较对角
                default: dx = 1; dy = -1   // 135° → 比较反对角
                }
                let x1 = max(0, min(width - 1, x - dx))
                let y1 = max(0, min(height - 1, y - dy))
                let x2 = max(0, min(width - 1, x + dx))
                let y2 = max(0, min(height - 1, y + dy))
                let lum1 = lumMap[y1 * width + x1]
                let lum2 = lumMap[y2 * width + x2]
                // 只抑制两侧都是不透明像素且亮度差小的边缘（花纹）。
                // 轮廓边缘（一侧透明，lum=0）保留。
                let bothOpaque = lum1 > 10 && lum2 > 10
                if bothOpaque && abs(lum1 - lum2) < stripeThreshold {
                    pixels[i] = 0
                    pixels[i + 1] = 0
                    pixels[i + 2] = 0
                    pixels[i + 3] = 0
                }
            }
        }
    }

    /// 将眼睛遮罩中的像素标记为实心填充（R=255），alpha=255。
    /// 这些像素在 encodeSlashLines 中被画为半块实心字符（▀/▄/█）而非斜线。
    private static func fillEyes(pixels: inout [UInt8], width: Int, height: Int, eyeMask: [Bool]) {
        let bpp = 4
        for y in 0..<height {
            for x in 0..<width {
                if eyeMask[y * width + x] {
                    let i = (y * width + x) * bpp
                    pixels[i] = 255     // R=255 标记为"实心"
                    pixels[i + 1] = 0
                    pixels[i + 2] = 0
                    pixels[i + 3] = 255
                }
            }
        }
    }
}
