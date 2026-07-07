// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalaryTrain",
    targets: [
        .target(
            name: "SalaryTrainCore",
            path: "Sources/SalaryTrainCore"
        ),
        .executableTarget(
            name: "SalaryTrain",
            dependencies: ["SalaryTrainCore"],
            path: "Sources/SalaryTrain"
        ),
        .testTarget(
            name: "SalaryTrainTests",
            dependencies: ["SalaryTrainCore"],
            path: "Tests/SalaryTrainTests"
        )
    ]
)
