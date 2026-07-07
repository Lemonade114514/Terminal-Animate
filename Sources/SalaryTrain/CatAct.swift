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

    init(stage: Stage, frames: [GifFrame], params: RenderParams = .bwEdge) {
        self.stage = stage
        self.gifFrames = frames
        self.params = params
    }

    var isFinished: Bool { false }

    func start() {
        started = true
        frameIndex = 0
        timeAccum = 0
        prerender()
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
        // 插帧：每对相邻帧之间插入 2 个插值帧，提升流畅度（25fps → 75fps 等效）
        let interpolated = GifLoader.interpolateFrames(gifFrames, framesPerOriginal: 2)
        let src = (interpolated[0].image.width, interpolated[0].image.height)
        let target = FrameRenderer.fitSize(source: src, terminal: cachedSize, reservedRows: cachedSize.rows / 2, verticalPixelsPerRow: 2)
        rendered = interpolated.map { frame in
            let resized = FrameRenderer.resize(frame.image, to: target)
            let lines = FrameRenderer.render(resized, params: params)
            return RenderedFrame(lines: lines, duration: frame.duration)
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
