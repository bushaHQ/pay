// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BushaPay",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(name: "BushaPay", targets: ["BushaPay"]),
    ],
    targets: [
        .target(
            name: "BushaPay",
            path: "Sources/BushaPay",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "BushaPayTests",
            dependencies: ["BushaPay"],
            path: "Tests/BushaPayTests"
        ),
    ]
)
