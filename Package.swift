// swift-tools-version: 5.9
// PatchDesk: a native macOS SwiftUI front-end for the Issue-to-Patch Agent CLI.
// Build on a Mac with: swift build   (then: swift run, or: open Package.swift in Xcode)
import PackageDescription

let package = Package(
    name: "PatchDesk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PatchDesk", targets: ["PatchDesk"])
    ],
    targets: [
        .executableTarget(
            name: "PatchDesk",
            path: "Sources/PatchDesk"
        ),
        .testTarget(
            name: "PatchDeskTests",
            dependencies: ["PatchDesk"],
            path: "Tests/PatchDeskTests"
        )
    ]
)
