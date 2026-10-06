// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tony",
    platforms: [.macOS(.v15)],
    dependencies: [
        // No traits: FluidAudio's default trait links an 87 MB text normalizer Tony never calls.
        .package(url: "https://github.com/FluidInference/FluidAudio", from: "0.17.5", traits: []),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Tony",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "TonyTests", dependencies: ["Tony"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
