// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NoSleep",
    platforms: [
        .macOS(.v10_13)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", from: "4.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "NoSleep",
            dependencies: ["LaunchAtLogin"],
            path: "Sources",
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/icon.svg"),
                .copy("Resources/AppIcon.svg")
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"]),
                .unsafeFlags(["-framework", "Foundation"])
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"]),
                .unsafeFlags(["-framework", "ServiceManagement"])
            ]
        ),
    ]
)
