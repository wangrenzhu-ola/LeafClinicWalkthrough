// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeafClinicWalkthrough",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LeafClinicWalkthrough", targets: ["LeafClinicWalkthrough"]),
        .executable(name: "LeafClinicPreviewHost", targets: ["LeafClinicPreviewHost"])
    ],
    targets: [
        .target(
            name: "LeafClinicWalkthrough",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "LeafClinicPreviewHost",
            dependencies: ["LeafClinicWalkthrough"]
        ),
        .testTarget(
            name: "LeafClinicWalkthroughTests",
            dependencies: ["LeafClinicWalkthrough"]
        )
    ]
)
