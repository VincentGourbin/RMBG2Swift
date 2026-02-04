// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

// RMBG2Swift - Background Removal using RMBG-2.0 CoreML Model
//
// This package uses the RMBG-2.0 model by BRIA AI.
// Original model: https://huggingface.co/briaai/RMBG-2.0
//
// License: Creative Commons Attribution-NonCommercial 4.0 (CC BY-NC 4.0)
// - Free for non-commercial use (research, personal projects, education)
// - Commercial use requires a separate license from BRIA AI:
//   https://bria.ai/contact-us
//
// Attribution: BRIA AI (https://bria.ai)

import PackageDescription

let package = Package(
    name: "RMBG2Swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RMBG2Swift",
            targets: ["RMBG2Swift"]),
        .executable(
            name: "rmbg2-cli",
            targets: ["RMBG2CLI"])
    ],
    targets: [
        .target(
            name: "RMBG2Swift",
            dependencies: [],
            path: "Sources/RMBG2Swift"
        ),
        .executableTarget(
            name: "RMBG2CLI",
            dependencies: ["RMBG2Swift"],
            path: "Examples/CLI"
        ),
        .testTarget(
            name: "RMBG2SwiftTests",
            dependencies: ["RMBG2Swift"]),
    ]
)
