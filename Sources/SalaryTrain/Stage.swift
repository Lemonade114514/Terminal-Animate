import Foundation
import SalaryTrainCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

final class Stage {
    static let reset = "\u{1b}[0m"
    static let defaultFG = "\u{1b}[39m"
    static let defaultBG = "\u{1b}[49m"
    static let hideCursor = "\u{1b}[?25l"
    static let showCursor = "\u{1b}[?25h"
    static let altScreen = "\u{1b}[?1049h"
    static let mainScreen = "\u{1b}[?1049l"
    static let home = "\u{1b}[H"
    static let clearScreen = "\u{1b}[2J"
    static let blackBG = "\u{1b}[48;2;0;0;0m"
    /// xterm 窗口调整序列：\x1b[8;rows;cols t
    static let resizeTo160x48 = "\u{1b}[8;48;160t"

    /// 固定终端尺寸 160×48。
    static let fixedSize = TerminalSize(columns: 160, rows: 48)

    var size: TerminalSize { Stage.fixedSize }
    private var previousBuffer: [String] = []

    init() {}

    func enter() {
        write(Stage.altScreen + Stage.hideCursor + Stage.reset + Stage.blackBG + Stage.resizeTo160x48 + Stage.clearScreen + Stage.home)
        fflush(stdout)
    }

    func exit() {
        write(Stage.reset + Stage.defaultBG + Stage.showCursor + Stage.clearScreen + Stage.mainScreen)
        fflush(stdout)
    }

    func clear() {
        previousBuffer = []
        write(Stage.reset + Stage.blackBG + Stage.clearScreen + Stage.home)
        fflush(stdout)
    }

    func draw(_ buffer: [String]) {
        var buf = buffer
        let cols = size.columns
        Overlay.stampQuitHint(into: &buf, cols: cols)
        var updates: [String] = []
        let force = previousBuffer.count != buf.count
        if force {
            previousBuffer = Array(repeating: "", count: buf.count)
        }
        for row in 0..<buf.count {
            if force || previousBuffer[row] != buf[row] {
                updates.append("\u{1b}[\(row + 1);1H\(buf[row])")
                previousBuffer[row] = buf[row]
            }
        }
        if !updates.isEmpty {
            write(updates.joined())
            fflush(stdout)
        }
    }

    private func write(_ s: String) {
        s.withCString { ptr in
            _ = Darwin.write(1, ptr, strlen(ptr))
        }
    }
}
