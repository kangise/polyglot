// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-translate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swift-translate", targets: ["SwiftTranslate"])
    ],
    targets: [
        .executableTarget(
            name: "SwiftTranslate",
            path: "Sources/SwiftTranslate"
        )
    ]
)
