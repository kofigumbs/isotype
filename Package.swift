// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Isotype",
    platforms: [
        .macOS(.v11),
    ],
    dependencies: [
        .package(url: "https://github.com/moosefactory/SwiftMIDI", revision: "c884e4a"),
    ],
    targets: [
        .executableTarget(name: "Isotype", dependencies: ["SwiftMIDI"]),
    ]
)
