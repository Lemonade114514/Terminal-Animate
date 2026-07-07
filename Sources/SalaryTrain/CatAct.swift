import Foundation
import SalaryTrainCore
import CoreGraphics

final class CatAct: Act {
    let stage: Stage
    private let gifFrames: [GifFrame]
    private let params: RenderParams
    private var rendered: [RenderedFrame] = []
    private var frameIndex: Int = 0
    private var timeAccum: Double = 0
    private var cachedSize: TerminalSize = TerminalSize(columns: 0, rows: 0)
    private var started = false
    private var preRenderedFrames: [RenderedFrame]? = nil
    private var isPrecomputing = false

    init(stage: Stage, frames: [GifFrame], params: RenderParams = .bwEdge) {
        self.stage = stage
        self.gifFrames = frames
        self.params = params
    }

    var isFinished: Bool { false }

    /// 在后台提前预渲染猫动画帧（在小火车阶段调用）。
    func precompute() {
        guard !isPrecomputing && preRenderedFrames == nil else { return }
        isPrecomputing = true
        let captureFrames = gifFrames
        let captureParams = params
        let captureSize = stage.size
        DispatchQueue.global().async { [weak self] in
            let frames = CatAct.doPrerender(gifFrames: captureFrames, params: captureParams, size: captureSize)
            DispatchQueue.main.async {
                self?.preRenderedFrames = frames
                self?.isPrecomputing = false
            }
        }
    }

    /// 后台预渲染的逻辑（纯静态函数，无 I/O 依赖）。
    private static func doPrerender(gifFrames: [GifFrame], params: RenderParams, size: TerminalSize) -> [RenderedFrame] {
        guard !gifFrames.isEmpty else { return [] }
        let src = (gifFrames[0].image.width, gifFrames[0].image.height)
        let target = FrameRenderer.fitSize(source: src, terminal: size, reservedRows: size.rows / 2, verticalPixelsPerRow: 2)
        let resizedFrames = gifFrames.map { frame in
            GifFrame(image: FrameRenderer.resize(frame.image, to: target), duration: frame.duration)
        }
        let pixelBuffers: [(pixels: [UInt8], width: Int, height: Int, duration: Double)] = resizedFrames.map { frame in
            let result = FrameRenderer.renderPixels(frame.image, params: params)
            return (pixels: result.pixels, width: result.width, height: result.height, duration: frame.duration)
        }
        let interpolated = FrameRenderer.interpolatePixelBuffers(pixelBuffers, framesPerOriginal: 1, mode: params.mode)
        return interpolated.map { buf in
            let lines: [String]
            if params.mode == .bwEdge {
                lines = FrameRenderer.encodeSlashLines(pixels: buf.pixels, width: buf.width, height: buf.height)
            } else {
                lines = FrameRenderer.encodeLines(pixels: buf.pixels, width: buf.width, height: buf.height)
            }
            return RenderedFrame(lines: lines, duration: buf.duration / 2.3)
        }
    }

    func start() {
        started = true
        frameIndex = 0
        timeAccum = 0
        if let pre = preRenderedFrames, cachedSize == stage.size {
            rendered = pre
            preRenderedFrames = nil
        } else {
            prerender()
        }
    }

    func step(elapsed: Double) {
        guard started else { return }
        if stage.size.columns != cachedSize.columns || stage.size.rows != cachedSize.rows {
            prerender()
        }
        timeAccum += elapsed
        let current = rendered[frameIndex]
        while timeAccum >= current.duration && !rendered.isEmpty {
            timeAccum -= current.duration
            frameIndex = (frameIndex + 1) % rendered.count
        }
        let frame = rendered[frameIndex]
        let cols = stage.size.columns
        let rows = stage.size.rows
        var screen: [String] = []
        let imageRows = frame.lines.count
        let topPad = max(0, (rows - imageRows) / 2)
        let blackLine = "\u{1b}[48;2;0;0;0m" + String(repeating: " ", count: cols) + "\u{1b}[0m"
        for _ in 0..<topPad {
            screen.append(blackLine)
        }
        for line in frame.lines {
            let lineLen = displayWidth(line)
            let leftPad = max(0, (cols - lineLen) / 2)
            let rightPad = max(0, cols - leftPad - lineLen)
            screen.append(
                "\u{1b}[48;2;0;0;0m"
                + String(repeating: " ", count: leftPad)
                + line
                + "\u{1b}[48;2;0;0;0m"
                + String(repeating: " ", count: rightPad)
                + "\u{1b}[0m"
            )
        }
        while screen.count < rows {
            screen.append(blackLine)
        }
        if screen.count > rows {
            screen = Array(screen.prefix(rows))
        }
        stage.draw(screen)
    }

    private func prerender() {
        cachedSize = stage.size
        guard !gifFrames.isEmpty else { return }
        // 1. 缩放所有帧（240×240 → target）
        let src = (gifFrames[0].image.width, gifFrames[0].image.height)
        let target = FrameRenderer.fitSize(source: src, terminal: cachedSize, reservedRows: cachedSize.rows / 2, verticalPixelsPerRow: 2)
        let resizedFrames = gifFrames.map { frame in
            GifFrame(image: FrameRenderer.resize(frame.image, to: target), duration: frame.duration)
        }
        // 2. 先对每帧做像素处理（Sobel/NMS/bw 等），得到 RGBA 像素缓冲
        let pixelBuffers: [(pixels: [UInt8], width: Int, height: Int, duration: Double)] = resizedFrames.map { frame in
            let result = FrameRenderer.renderPixels(frame.image, params: params)
            return (pixels: result.pixels, width: result.width, height: result.height, duration: frame.duration)
        }
        // 3. 在已渲染的像素缓冲上插值（边缘检测在干净帧上完成，插值只混合最终像素）
        let interpolated = FrameRenderer.interpolatePixelBuffers(pixelBuffers, framesPerOriginal: 1, mode: params.mode)
        // 4. 编码为 ANSI 字符串
        rendered = interpolated.map { buf in
            let lines: [String]
            if params.mode == .bwEdge {
                lines = FrameRenderer.encodeSlashLines(pixels: buf.pixels, width: buf.width, height: buf.height)
            } else {
                lines = FrameRenderer.encodeLines(pixels: buf.pixels, width: buf.width, height: buf.height)
            }
            return RenderedFrame(lines: lines, duration: buf.duration / 2.3)
        }
        frameIndex %= max(1, rendered.count)
    }

    private func displayWidth(_ s: String) -> Int {
        var w = 0
        var inEscape = false
        for ch in s {
            if ch == "\u{1b}" {
                inEscape = true
                continue
            }
            if inEscape {
                if ch == "m" || ch == "H" || ch == "J" {
                    inEscape = false
                }
                continue
            }
            w += 1
        }
        return w
    }
}
