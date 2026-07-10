import Foundation
#if canImport(Darwin)
import Darwin
#endif

private var sigintFlag: Int32 = 0

final class Show {
    private let stage: Stage
    private let trainAct: TrainAct
    private let catAct: CatAct
    private let tickInterval: useconds_t = 16_000

    private static let sigintHandler: @convention(c) (Int32) -> Void = { _ in
        sigintFlag = 1
    }

    init(stage: Stage, trainAct: TrainAct, catAct: CatAct) {
        self.stage = stage
        self.trainAct = trainAct
        self.catAct = catAct
    }

    func run() {
        sigintFlag = 0
        signal(SIGINT, Show.sigintHandler)
        stage.enter()
        defer { stage.exit() }

        trainAct.start()
        catAct.precompute()
        var last = currentTime()
        while sigintFlag == 0 && !trainAct.isFinished {
            let now = currentTime()
            let elapsed = now - last
            last = now
            trainAct.step(elapsed: elapsed)
            usleep(tickInterval)
        }

        if sigintFlag != 0 { return }
        stage.clear()

        catAct.start()
        last = currentTime()
        while sigintFlag == 0 {
            let now = currentTime()
            let elapsed = now - last
            last = now
            catAct.step(elapsed: elapsed)
            usleep(tickInterval)
        }
    }

    func runCatOnly() {
        sigintFlag = 0
        signal(SIGINT, Show.sigintHandler)
        stage.enter()
        defer { stage.exit() }

        catAct.start()
        var last = currentTime()
        while sigintFlag == 0 {
            let now = currentTime()
            let elapsed = now - last
            last = now
            catAct.step(elapsed: elapsed)
            usleep(tickInterval)
        }
    }

    private func currentTime() -> Double {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000.0
    }
}
