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

    var size: TerminalSize { Stage.readSize() }
    private var previousBuffer: [String] = []

    init() {}

    func enter() {
        write(Stage.altScreen + Stage.hideCursor + Stage.reset + Stage.blackBG + Stage.clearScreen + Stage.home)
        fflush(stdout)
    }

    func exit() {
        write(Stage.reset + Stage.defaultBG + Stage.showCursor + Stage.mainScreen)
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

    private static func readSize() -> TerminalSize {
        var ws = winsize()
        let err = ioctl(1, TIOCGWINSZ, &ws)
        if err == 0 && Int(ws.ws_col) > 0 && Int(ws.ws_row) > 0 {
            return TerminalSize(columns: Int(ws.ws_col), rows: Int(ws.ws_row))
        }
        let cols = ProcessInfo.processInfo.environment["COLUMNS"].flatMap(Int.init) ?? 80
        let rows = ProcessInfo.processInfo.environment["LINES"].flatMap(Int.init) ?? 24
        return TerminalSize(columns: max(1, cols), rows: max(2, rows))
    }

    private func write(_ s: String) {
        s.withCString { ptr in
            _ = Darwin.write(1, ptr, strlen(ptr))
        }
    }
}
