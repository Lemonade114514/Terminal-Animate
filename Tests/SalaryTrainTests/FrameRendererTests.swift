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
        XCTAssertFalse(joined.contains("\u{2580}"), "bwEdge must not use half-block top char ▀")
        XCTAssertFalse(joined.contains("\u{2584}"), "bwEdge must not use half-block bottom char ▄")
    }
}
