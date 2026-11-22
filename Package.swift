// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tony",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Our fork until a FluidAudio release keeps Parakeet to the user's letters (ADR 0010).
        // No traits: FluidAudio's default trait links an 87 MB text normalizer Tony never calls.
        .package(url: "https://github.com/bestboyhq/FluidAudio", revision: "d078d6b5cac495c04f36bce8cef614ea11385ed2", traits: []),
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
