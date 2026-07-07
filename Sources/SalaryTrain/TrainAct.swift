import Foundation
import SalaryTrainCore
final class TrainAct: Act {
    let stage: Stage

    /// Locomotive colour (classic sl is light-on-black; silver reads well).
    private let trainColor = "\u{1b}[38;2;200;200;210;48;2;0;0;0m"
    private let blackBG = "\u{1b}[48;2;0;0;0m"
    private let reset = "\u{1b}[0m"

    private let frameInterval: Double = 0.04   // sl uses usleep(40000)
    private var timeAccum: Double = 0
    private var trainX: Int = 0
    private var started = false
    private let smoke = SmokeSystem()
    private var slFrame: Int = 0                 // counts sl frames (40ms each)

    init(stage: Stage, speed: Double = 30) {
        self.stage = stage
        // speed ignored: we replicate sl's exact 1-col / 40ms cadence.
    }

    var isFinished: Bool {
        guard started else { return false }
        return trainX + D51_LENGTH < 0
    }

    func start() {
        started = true
        trainX = stage.size.columns
        timeAccum = 0
        slFrame = 0
    }

    func step(elapsed: Double) {
        guard started else { return }
        timeAccum += elapsed
        while timeAccum >= frameInterval {
            timeAccum -= frameInterval
            trainX -= 1
            slFrame += 1
            let topRow = stage.size.rows / 2 - 5
            smoke.tick(
                spawnY: topRow - 1,
                spawnX: trainX + D51_FUNNEL_X,
                frameMod4: slFrame % 4
            )
        }
        render()
    }

    private func render() {
        let cols = stage.size.columns
        let rows = stage.size.rows
        let topRow = rows / 2 - 5

        // Char grid (all spaces = black background).
        var grid: [[Character]] = Array(
            repeating: Array(repeating: " ", count: cols),
            count: rows
        )

        // Stamp the D51 + coal sprite at (topRow, trainX).
        let pattern = ((D51_LENGTH + trainX) % D51_PATTERNS + D51_PATTERNS) % D51_PATTERNS
        let sprite = d51Sprite(wheelPattern: pattern)
        for (i, line) in sprite.enumerated() {
            let row = topRow + i
            guard row >= 0 && row < rows else { continue }
            for (j, ch) in line.enumerated() {
                guard ch != " " else { continue }
                let col = trainX + j
                guard col >= 0 && col < cols else { continue }
                grid[row][col] = ch
            }
        }

        // Stamp smoke placements (absolute screen coords).
        for p in smoke.placements() {
            var gx = p.x
            for ch in p.glyph {
                if gx >= 0 && gx < cols && p.y >= 0 && p.y < rows {
                    grid[p.y][gx] = ch
                }
                gx += 1
            }
        }

        // Convert grid to ANSI lines: non-space -> silver on black, space -> black bg.
        let buffer = grid.map { row -> String in
            var parts: [String] = [trainColor]
            var run = ""
            for ch in row {
                if ch != " " {
                    run.append(ch)
                } else {
                    run.append(" ")
                }
            }
            parts.append(run)
            parts.append(reset)
            return parts.joined()
        }
        stage.draw(buffer)
    }
}
