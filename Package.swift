// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BurningTrackPioneerDeckExport",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BurningTrackPioneerDeckExport",
            targets: ["BurningTrackPioneerDeckExport"]
        )
    ],
    targets: [
        .target(
            name: "BurningTrackPioneerDeckExport",
            path: "TrackList/Integrations/PioneerDeckExport",
            exclude: ["Adapters"]
        ),
        .testTarget(
            name: "BurningTrackPioneerDeckExportTests",
            dependencies: ["BurningTrackPioneerDeckExport"],
            path: "TrackListTests/PioneerDeckExport"
        )
    ]
)
