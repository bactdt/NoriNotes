// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoriNotes",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NoriNotes", targets: ["NoriNotes"])
    ],
    targets: [
        .executableTarget(name: "NoriNotes", path: "Sources/NoriNotes"),
        .testTarget(name: "NoriNotesTests", dependencies: ["NoriNotes"], path: "Tests/NoriNotesTests")
    ]
)
