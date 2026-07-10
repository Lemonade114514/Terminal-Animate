import Foundation
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
    static let resizeTo240x40 = "\u{1b}[8;40;240t"

    /// 固定终端尺寸 240×40。
    static let fixedSize = TerminalSize(columns: 240, rows: 40)

    var size: TerminalSize { Stage.fixedSize }
    private var previousBuffer: [String] = []

    init() {}

    func enter() {
        write(Stage.altScreen + Stage.hideCursor + Stage.reset + Stage.blackBG + Stage.resizeTo240x40 + Stage.clearScreen + Stage.home)
        fflush(stdout)
        usleep(300_000)
        centerWindow()
    }

    /// macOS: 通过 AppleScript 将 Terminal 窗口居中。
    /// 等待 resize 完成后用 set bounds 替代 set position，更可靠。
    private func centerWindow() {
        let script = """
        tell application "System Events"
            set screenSize to size of first screen whose index = 0
        end tell
        tell application "Terminal"
            set win to front window
            set {left, top, right, bottom} to bounds of win
            set windowWidth to right - left
            set windowHeight to bottom - top
            set newX to ((item 1 of screenSize) - windowWidth) / 2
            set newY to ((item 2 of screenSize) - windowHeight + 25) / 2
            set bounds of win to {newX, newY, newX + windowWidth, newY + windowHeight}
        end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        do { try task.run() } catch { fputs("[centerWindow] osascript failed: \(error.localizedDescription)\n", stderr) }
        task.waitUntilExit()
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
            var offset = 0
            let total = strlen(ptr)
            while offset < total {
                let written = Darwin.write(1, ptr.advanced(by: offset), total - offset)
                if written <= 0 { break }
                offset += written
            }
        }
    }
}
