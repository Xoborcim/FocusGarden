// swift-tools-version: 5.9
    import PackageDescription
                                                                                                                                                                                                            
    let package = Package(
        name: "FocusGarden",
        defaultLocalization: "en",
        platforms: [.iOS(.v17), .macOS(.v14)],
        products: [
            .library(name: "FocusGarden", type: .dynamic, targets: ["FocusGarden"]),
        ],
        dependencies: [
            .package(url: "https://github.com/skiptools/skip.git", from: "1.1.0"),
            .package(url: "https://github.com/skiptools/skip-foundation.git", from: "1.0.0"),
            .package(url: "https://github.com/skiptools/skip-ui.git", from: "1.0.0"),
            .package(url: "https://github.com/skiptools/skip-model.git", from: "1.0.0"),
        ],
        targets: [
            .target(
                name: "FocusGarden",
                dependencies: [
                    .product(name: "SkipFoundation", package: "skip-foundation"),
                    .product(name: "SkipUI", package: "skip-ui"),
                    .product(name: "SkipModel", package: "skip-model"),
                ],
                path: "FocusGarden",
                resources: [.process("Resources")],
                plugins: [.plugin(name: "skipstone", package: "skip")]
            ),
            .testTarget(
                name: "FocusGardenTests",
                dependencies: [
                    "FocusGarden",
                    .product(name: "SkipTest", package: "skip"),
                ],
                path: "FocusGardenTests",
                plugins: [.plugin(name: "skipstone", package: "skip")]
            ),
        ]
    )               
