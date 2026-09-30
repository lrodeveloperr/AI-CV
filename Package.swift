// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AICVEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AICVEngine",
            targets: [
                "CareerDomain",
                "CareerWorkflow",
                "DocumentEngine",
                "PersistenceSync",
                "AIImport",
                "Purchases"
            ]
        )
    ],
    targets: [
        .target(name: "CareerDomain"),
        .target(
            name: "CareerWorkflow",
            dependencies: ["CareerDomain"]
        ),
        .target(
            name: "DocumentEngine",
            dependencies: ["CareerDomain"]
        ),
        .target(
            name: "PersistenceSync",
            dependencies: ["CareerDomain", "CareerWorkflow"]
        ),
        .target(
            name: "AIImport",
            dependencies: ["CareerDomain"]
        ),
        .target(
            name: "Purchases",
            dependencies: ["CareerDomain"]
        ),
        .testTarget(
            name: "CareerDomainTests",
            dependencies: ["CareerDomain"]
        ),
        .testTarget(
            name: "CareerWorkflowTests",
            dependencies: ["CareerDomain", "CareerWorkflow"]
        ),
        .testTarget(
            name: "DocumentEngineTests",
            dependencies: ["CareerDomain", "DocumentEngine"]
        ),
        .testTarget(
            name: "PersistenceSyncTests",
            dependencies: ["CareerDomain", "CareerWorkflow", "PersistenceSync"]
        ),
        .testTarget(
            name: "AIImportTests",
            dependencies: ["CareerDomain", "AIImport"]
        ),
        .testTarget(
            name: "PurchasesTests",
            dependencies: ["CareerDomain", "Purchases"]
        )
    ]
)

