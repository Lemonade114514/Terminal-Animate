import XCTest
@testable import SalaryTrainCore
import CoreGraphics
import ImageIO

final class FrameRendererTests: XCTestCase {

    /// 合成一个 W×H 的 CGImage：x=5..14, y=5..14 是白色不透明方块，其余透明。
    private func makeWhiteSquareImage() -> CGImage {
        let W = 20, H = 20
        var pixels = [UInt8](repeating: 0, count: W * H * 4)
        for y in 5..<15 {
            for x in 5..<15 {
                let i = (y * W + x) * 4
                pixels[i] = 255; pixels[i + 1] = 255; pixels[i + 2] = 255; pixels[i + 3] = 255
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &pixels, width: W, height: H,
            bitsPerComponent: 8, bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }

    /// 取中间行 y=10 的左边缘区 (x=4, x=5)，数有几个像素是边缘（alpha=255）。
    /// 硬边缘应该只有 1 个像素被标记为边缘（NMS 细化）。
    func testBwEdgeHardEdgeIsOnePixelWide() {
        let image = makeWhiteSquareImage()
        let result = FrameRenderer.renderPixels(image, params: .bwEdge)
        let pixels = result.pixels
        let w = result.width
        let y = 10
        let x4Alpha = Int(pixels[(y * w + 4) * 4 + 3])
        let x5Alpha = Int(pixels[(y * w + 5) * 4 + 3])
        let edgeCount = [x4Alpha, x5Alpha].filter { $0 >= 200 }.count
        XCTAssertEqual(edgeCount, 1, "hard edge should be exactly 1px after NMS, got \(edgeCount) (x4=\(x4Alpha), x5=\(x5Alpha))")
    }

    /// 全透明图 → bwEdge 不应凭空造出任何边缘。
    func testBwEdgeTransparentImageHasNoEdges() {
        let W = 10, H = 10
        let pixels = [UInt8](repeating: 0, count: W * H * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: UnsafeMutablePointer(mutating: pixels), width: W, height: H,
            bitsPerComponent: 8, bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = ctx.makeImage()!
        let result = FrameRenderer.renderPixels(image, params: .bwEdge)
        let opaqueCount = result.pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element >= 200 }.count
        XCTAssertEqual(opaqueCount, 0, "fully transparent image must produce no edges")
    }

    /// bw 模式（白剪影）不应受 NMS 影响 —— 方块内部应全不透明。
    func testBwModeUnaffectedByNMS() {
        let image = makeWhiteSquareImage()
        let result = FrameRenderer.renderPixels(image, params: .bw)
        let pixels = result.pixels
        let w = result.width
        // 方块内部 x=8..12, y=8..12 应全部不透明（alpha=255）
        var allOpaque = true
        for y in 8..<13 {
            for x in 8..<13 {
                let a = Int(pixels[(y * w + x) * 4 + 3])
                if a < 200 { allOpaque = false }
            }
        }
        XCTAssertTrue(allOpaque, "bw mode must keep silhouette interior fully opaque (NMS only affects Sobel paths)")
    }

    /// 猫高度减半：fitSize 用 reservedRows = rows/2 时，目标终端行数 ≤ rows/2。
    func testFitSizeHalfHeightCatFitsInHalfTerminal() {
        let rows = 40
        let terminal = TerminalSize(columns: 100, rows: rows)
        let target = FrameRenderer.fitSize(source: (174, 157), terminal: terminal, reservedRows: rows / 2)
        let targetTerminalRows = (target.1 + 1) / 2
        XCTAssertLessThanOrEqual(targetTerminalRows, rows / 2,
            "cat should fit in half the terminal: got \(targetTerminalRows) rows, max \(rows / 2)")
    }

    /// bwEdge 像素处理：所有不透明像素的 R 通道必须是方向码 (0-3)。
    func testBwEdgeOpaquePixelsStoreDirectionCode() {
        let image = makeWhiteSquareImage()
        let result = FrameRenderer.renderPixels(image, params: .bwEdge)
        let pixels = result.pixels
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Int(pixels[i + 3])
            if a >= 200 {
                let dirCode = Int(pixels[i])
                XCTAssertTrue(dirCode >= 0 && dirCode <= 3,
                    "edge pixel R must be direction code 0-3 at index \(i), got \(dirCode)")
            }
        }
    }

    /// bwEdge 编码输出：用 /\|- 画边缘，不用半块字符 ▀▄█。
    func testBwEdgeOutputUsesSlashCharsNotBlocks() {
        let image = makeWhiteSquareImage()
        let lines = FrameRenderer.render(image, params: .bwEdge)
        let joined = lines.joined()
        XCTAssertTrue(joined.contains("|") || joined.contains("/") || joined.contains("-") || joined.contains("\\"),
            "bwEdge output must contain slash/pipe/dash chars for edges")
        // 白色方块没有蓝色像素（眼睛），所以不应有实心块
        XCTAssertFalse(joined.contains("\u{2588}"), "bwEdge must not use full block █ for non-eye pixels")
    }

    /// 合成带蓝色眼睛区域的图像：白色不透明背景 + 中心蓝色方块（眼睛）。
    private func makeImageWithBlueEyes() -> CGImage {
        let W = 30, H = 30
        var pixels = [UInt8](repeating: 0, count: W * H * 4)
        // 白色背景 (x=2..27, y=2..27)
        for y in 2..<28 {
            for x in 2..<28 {
                let i = (y * W + x) * 4
                pixels[i] = 255; pixels[i + 1] = 255; pixels[i + 2] = 255; pixels[i + 3] = 255
            }
        }
        // 蓝色眼睛区域 (x=10..19, y=10..19) — B > R+30, B > G+10
        for y in 10..<20 {
            for x in 10..<20 {
                let i = (y * W + x) * 4
                pixels[i] = 50; pixels[i + 1] = 80; pixels[i + 2] = 160; pixels[i + 3] = 255
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &pixels, width: W, height: H,
            bitsPerComponent: 8, bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }

    /// bwEdge 眼睛检测：蓝色像素区域应被标记为 R=255（实心）。
    func testBwEdgeEyesAreDetectedAndFilled() {
        let image = makeImageWithBlueEyes()
        let result = FrameRenderer.renderPixels(image, params: .bwEdge)
        let pixels = result.pixels
        let w = result.width
        // 蓝色眼睛中心 (x=14, y=14) 应被标记为 R=255（实心填充）
        let eyeCenterIdx = (14 * w + 14) * 4
        let eyeCenterR = Int(pixels[eyeCenterIdx])
        let eyeCenterA = Int(pixels[eyeCenterIdx + 3])
        XCTAssertEqual(eyeCenterR, 255, "eye pixel R must be 255 (solid marker)")
        XCTAssertEqual(eyeCenterA, 255, "eye pixel must be opaque")
    }

    /// bwEdge 眼睛编码：应输出实心块字符（▀/▄/█）。
    func testBwEdgeEyesRenderedAsSolidBlocks() {
        let image = makeImageWithBlueEyes()
        let lines = FrameRenderer.render(image, params: .bwEdge)
        let joined = lines.joined()
        // 眼睛区域应产生实心块字符
        XCTAssertTrue(joined.contains("\u{2588}") || joined.contains("\u{2580}") || joined.contains("\u{2584}"),
            "bwEdge eyes must be rendered as solid blocks (█/▀/▄), got: \(joined.prefix(200))")
    }

    /// bwEdge 花纹过滤：合成一个亮度差很小但颜色差大的"花纹"边缘，验证被抑制。
    func testBwEdgeStripeEdgesAreFiltered() {
        let W = 20, H = 20
        var pixels = [UInt8](repeating: 0, count: W * H * 4)
        // 左半 (x=0..9)：浅棕 (200, 180, 150) — 亮度 ~186
        for y in 0..<H {
            for x in 0..<10 {
                let i = (y * W + x) * 4
                pixels[i] = 200; pixels[i + 1] = 180; pixels[i + 2] = 150; pixels[i + 3] = 255
            }
        }
        // 右半 (x=10..19)：深棕 (170, 160, 150) — 亮度 ~162, 差 24 < stripeThreshold 30
        for y in 0..<H {
            for x in 10..<20 {
                let i = (y * W + x) * 4
                pixels[i] = 170; pixels[i + 1] = 160; pixels[i + 2] = 150; pixels[i + 3] = 255
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &pixels, width: W, height: H,
            bitsPerComponent: 8, bytesPerRow: W * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = ctx.makeImage()!
        let result = FrameRenderer.renderPixels(image, params: .bwEdge)
        let outPixels = result.pixels
        // x=9..11 区域（花纹边缘）应被抑制：不透明像素应该很少
        var edgeCount = 0
        for y in 5..<15 {
            for x in 8..<13 {
                let a = Int(outPixels[(y * W + x) * 4 + 3])
                if a >= 200 { edgeCount += 1 }
            }
        }
        XCTAssertLessThanOrEqual(edgeCount, 5,
            "stripe edges (small luminance diff) should be suppressed: got \(edgeCount) edge pixels in boundary zone")
    }
}
