import ProjectDescription

let project = Project(
    name: "ExitCodeClubCIAutomationApp",
    packages: [
        .package(
            url: "https://github.com/kstenerud/KSCrash.git",
            .branch("ac-working")
        ),
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "5.10",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ARCHS": "arm64",
        "ONLY_ACTIVE_ARCH": "YES",
    ]),
    targets: [
        .target(
            name: "CrashGeneratorsObjC",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.exitcodeclub.ci.automation.crashgeneratorsobjc",
            deploymentTargets: .iOS("17.0"),
            sources: ["CrashGeneratorsObjC/Sources/**"],
            headers: .headers(public: ["CrashGeneratorsObjC/Sources/include/**"]),
            settings: .settings(base: [
                "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
            ])
        ),
        .target(
            name: "ExitCodeClubCIAutomationApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.exitcodeclub.ci.automation.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleDisplayName": "ECC CI Crash",
            ]),
            sources: ["ExitCodeClubCIAutomationApp/Sources/**"],
            scripts: [
                .post(
                    script: """
                    "${SRCROOT}/scripts/upload-dsyms-ci.sh" \
                      --backend-url "https://kscrash-api-765738384004.us-central1.run.app" \
                      --dsym-folder "${BUILT_PRODUCTS_DIR}"
                    """,
                    name: "Upload dSYMs",
                    basedOnDependencyAnalysis: false,
                    shellPath: "/bin/bash"
                ),
            ],
            dependencies: [
                .target(name: "CrashGeneratorsObjC"),
                .package(product: "Recording", type: .runtime),
                .package(product: "Installations", type: .runtime),
                .package(product: "Filters", type: .runtime),
                .package(product: "DemangleFilter", type: .runtime),
            ]
        ),
        .target(
            name: "ExitCodeClubCIAutomationAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.exitcodeclub.ci.automation.app.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["ExitCodeClubCIAutomationApp/Tests/**"],
            dependencies: [
                .target(name: "ExitCodeClubCIAutomationApp"),
            ]
        ),
        .target(
            name: "ExitCodeClubCIAutomationAppUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.exitcodeclub.ci.automation.app.uitests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["ExitCodeClubCIAutomationApp/UITests/**"],
            dependencies: [
                .target(name: "ExitCodeClubCIAutomationApp"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "ExitCodeClubCIAutomationApp",
            shared: true,
            buildAction: .buildAction(targets: ["ExitCodeClubCIAutomationApp"]),
            testAction: .targets(
                ["ExitCodeClubCIAutomationAppTests", "ExitCodeClubCIAutomationAppUITests"],
                configuration: .release,
                attachDebugger: false
            ),
            runAction: .runAction(executable: "ExitCodeClubCIAutomationApp")
        )
    ]
)
