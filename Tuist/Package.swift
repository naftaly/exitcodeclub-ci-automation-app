// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(productTypes: [:])
#endif

let package = Package(
    name: "ExitCodeClubCIAutomationApp",
    dependencies: [
        // Keep empty; app dependencies are declared in Project.swift packages.
    ]
)
