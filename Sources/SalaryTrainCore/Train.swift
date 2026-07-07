import Foundation

// MARK: - Canonical sl (D51 + coal tender) art, ported from sl.h.
// All strings are ASCII so Character.count == display width.
// D51LENGTH = 83 (53 locomotive + 30 coal). D51HEIGHT = 10. D51PATTERNS = 6.

private let D51STR: [String] = [
    "      ====        ________                ___________ ",
    "  _D _|  |_______/        \\__I_I_____===__|_________| ",
    "   |(_)---  |   H\\________/ |   |        =|___ ___|   ",
    "   /     |  |   H  |  |     |   |         ||_| |_||   ",
    "  |      |  |   H  |__--------------------| [___] |   ",
    "  | ________|___H__/__|_____/[][]~\\_______|       |   ",
    "  |/ |   |-----------I_____I [][] []  D   |=======|__ "
]

private let D51WHL: [[String]] = [
    ["__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ ",
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        ",
     "  \\_/      \\O=====O=====O=====O_/      \\_/            "],
    ["__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ ",
     " |/-=|___|=O=====O=====O=====O   |_____/~\\___/        ",
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            "],
    ["__/ =| o |=-O=====O=====O=====O \\ ____Y___________|__ ",
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        ",
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            "],
    ["__/ =| o |=-~O=====O=====O=====O\\ ____Y___________|__ ",
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        ",
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            "],
    ["__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ ",
     " |/-=|___|=   O=====O=====O=====O|_____/~\\___/        ",
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            "],
    ["__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ ",
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        ",
     "  \\_/      \\_O=====O=====O=====O/      \\_/            "]
]

private let COAL: [String] = [
    "                              ",
    "                              ",
    "    _________________         ",
    "   _|                \\_____A  ",
    " =|                        |  ",
    " -|                        |  ",
    "__|________________________|_ ",
    "|__________________________|_ ",
    "   |_D__D__D_|  |_D__D__D_|   ",
    "    \\_/   \\_/    \\_/   \\_/    "
]

public let D51_LENGTH = 83
public let D51_HEIGHT = 10
public let D51_PATTERNS = 6
public let D51_FUNNEL_X = 7   // smoke spawns at locomotive column +7

/// Compose the 10-row, 83-col D51 + coal sprite for a given wheel pattern (0..5).
public func d51Sprite(wheelPattern: Int) -> [String] {
    let p = ((wheelPattern % D51_PATTERNS) + D51_PATTERNS) % D51_PATTERNS
    var rows: [String] = []
    for i in 0..<7 {
        let body = D51STR[i]
        let bodyPart = String(body.prefix(53))
        let coalPart = COAL[i]
        rows.append((bodyPart + coalPart).padding(toLength: D51_LENGTH, withPad: " ", startingAt: 0))
    }
    for i in 0..<3 {
        let wheel = D51WHL[p][i]
        let wheelPart = String(wheel.prefix(53))
        let coalPart = COAL[7 + i]
        rows.append((wheelPart + coalPart).padding(toLength: D51_LENGTH, withPad: " ", startingAt: 0))
    }
    return rows
}

// MARK: - Smoke (ported add_smoke)

private let SMOKE_PATTERNS = 16
private let SMOKE: [[String]] = [
    ["(   )", "(    )", "(    )", "(   )", "(  )",
     "(  )", "( )", "( )", "()", "()",
     "O", "O", "O", "O", "O", " "],
    ["(@@@)", "(@@@@)", "(@@@@)", "(@@@)", "(@@)",
     "(@@)", "(@)", "(@)", "@@", "@@",
     "@", "@", "@", "@", "@", " "]
]
private let SMOKE_DY: [Int] = [2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
private let SMOKE_DX: [Int] = [-2, -1, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3]

public struct SmokeParticle {
    public var y: Int
    public var x: Int
    public var ptrn: Int
    public var kind: Int
    public init(y: Int, x: Int, ptrn: Int, kind: Int) {
        self.y = y; self.x = x; self.ptrn = ptrn; self.kind = kind
    }
}

public final class SmokeSystem {
    private var particles: [SmokeParticle] = []
    private var sum = 0

    public init() {}

    /// Advance existing particles and maybe spawn one at (y, x). `frameMod4` is the caller's frame counter mod 4.
    public func tick(spawnY: Int, spawnX: Int, frameMod4: Int) {
        for i in 0..<particles.count {
            particles[i].y -= SMOKE_DY[particles[i].ptrn]
            particles[i].x += SMOKE_DX[particles[i].ptrn]
            if particles[i].ptrn < SMOKE_PATTERNS - 1 { particles[i].ptrn += 1 }
        }
        particles.removeAll { $0.ptrn >= SMOKE_PATTERNS - 1 && SMOKE[$0.kind][$0.ptrn] == " " }
        if frameMod4 == 0 {
            particles.append(SmokeParticle(y: spawnY, x: spawnX, ptrn: 0, kind: sum % 2))
            sum += 1
        }
    }

    public func placements() -> [(y: Int, x: Int, glyph: String)] {
        particles.compactMap { p in
            let glyph = SMOKE[p.kind][p.ptrn]
            return glyph == " " ? nil : (p.y, p.x, glyph)
        }
    }
}
