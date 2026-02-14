// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "UnfollowChecker",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "UnfollowChecker",
            targets: ["UnfollowChecker"]
        ),
    ],
    targets: [
        .target(
            name: "UnfollowChecker",
            path: "UnfollowChecker"
        ),
        .testTarget(
            name: "UnfollowCheckerTests",
            dependencies: ["UnfollowChecker"],
            path: "UnfollowCheckerTests"
        ),
    ]
)
