// swift-tools-version:5.9

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import PackageDescription

let package = Package(
    name: "PurgeMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PurgeMacCore", targets: ["PurgeMacCore"]),
        .executable(name: "PurgeMacCLI", targets: ["PurgeMacCLI"]),
        .executable(name: "PurgeMacGUI", targets: ["PurgeMacGUI"]),
        .executable(name: "PurgeMacHelper", targets: ["PurgeMacHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "PurgeMacCore"),
        .executableTarget(
            name: "PurgeMacCLI",
            dependencies: ["PurgeMacCore"]
        ),
        .executableTarget(
            name: "PurgeMacGUI",
            dependencies: [
                "PurgeMacCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .executableTarget(
            name: "PurgeMacHelper",
            dependencies: ["PurgeMacCore"],
            resources: [.process("io.github.jia-liu.PurgeMac.helper.plist")]
        ),
    ]
)
