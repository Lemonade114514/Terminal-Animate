import Foundation

/// 恒定提示层（纯函数，可测）。
public enum Overlay {
    /// 左下角恒定显示的退出提示文本。
    public static let quitHintText = "Quit: Ctrl+C"

    /// 暗灰前景色 ANSI 码。
    private static let grayFG = "\u{1b}[38;2;100;100;100m"

    /// 返回完整最后一行 ANSI：黑底 + 暗灰 "Quit: Ctrl+C" + 空格补齐到 cols 宽 + reset。
    public static func quitHintRow(cols: Int) -> String {
        let hint = quitHintText
        let padding = max(0, cols - hint.count)
        return FrameRenderer.blackBG + grayFG + hint
            + FrameRenderer.blackBG + String(repeating: " ", count: padding)
            + FrameRenderer.reset
    }

    /// 把 buffer 最后一行替换为 quitHintRow(cols:)，其余行不动。
    public static func stampQuitHint(into buffer: inout [String], cols: Int) {
        guard !buffer.isEmpty else { return }
        buffer[buffer.count - 1] = quitHintRow(cols: cols)
    }
}
