import Foundation
import SalaryTrainCore
protocol Act: AnyObject {
    var stage: Stage { get }
    var isFinished: Bool { get }

    func start()
    func step(elapsed: Double)
}
