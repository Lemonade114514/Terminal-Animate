import XCTest
@testable import SalaryTrainCore

final class OverlayTests: XCTestCase {
    func testQuitHintTextIsQuitCtrlC() {
        XCTAssertEqual(Overlay.quitHintText, "Quit: Ctrl+C")
    }

    func testQuitHintRowStartsWithHintAndFillsWidth() {
        let row = Overlay.quitHintRow(cols: 80)
        let visible = stripANSI(row)
        XCTAssertEqual(visible.count, 80, "row must fill exactly cols visible chars")
        XCTAssertTrue(visible.hasPrefix("Quit: Ctrl+C"), "row must start with the hint text")
    }

    func testStampQuitHintReplacesLastLineKeepsOthers() {
        var buffer = ["line0", "line1", "line2"]
        let originalExceptLast = buffer.dropLast()
        Overlay.stampQuitHint(into: &buffer, cols: 40)
        XCTAssertEqual(buffer.count, 3, "must not change row count")
        XCTAssertEqual(Array(buffer.dropLast()), Array(originalExceptLast), "must keep non-last rows unchanged")
        let lastVisible = stripANSI(buffer.last!)
        XCTAssertEqual(lastVisible.count, 40)
        XCTAssertTrue(lastVisible.hasPrefix("Quit: Ctrl+C"))
    }

    private func stripANSI(_ s: String) -> String {
        var out = ""
        var inEsc = false
        for ch in s {
            if ch == "\u{1b}" { inEsc = true; continue }
            if inEsc {
                if ch.isLetter { inEsc = false }
                continue
            }
            out.append(ch)
        }
        return out
    }
}
