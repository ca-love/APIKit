// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "APIKit",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)
    ],
    products: [
        .library(name: "APIKit", targets: ["APIKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "APIKit", 
            dependencies: [],
            exclude: ["BodyParameters/AbstractInputStream.m"]
        ),
         .testTarget(
            name: "APIKitTests",
            dependencies: ["APIKit"],
            resources: [.process("Resources")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
