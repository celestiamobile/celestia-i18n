// swift-tools-version: 5.9
//
// Package.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import PackageDescription

let package = Package(
    name: "celestia-i18n",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "FormatterApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "Core")
            ]
        ),
        .executableTarget(
            name: "UpdaterApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "Core")
            ]
        ),
        .executableTarget(
            name: "ExtractorApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "Core")
            ]
        ),
        .target(name: "Core", dependencies: [])
    ]
)
