//
// App.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import ArgumentParser
import Core
import Foundation

@main
struct Extractor: AsyncParsableCommand {
    @Argument
    var appleRootPath: String

    @Argument
    var androidRootPath: String

    @Argument
    var windowsRootPath: String

    @Argument
    var templatePath: String

    func run() async throws {
        let templateURL = URL(filePath: templatePath)
        let pot = try Parser.parsePOTemplate(at: templateURL)
        let entries = try Core.Extractor.extractStrings(appleRoot: URL(filePath: appleRootPath), androidRoot: URL(filePath: androidRootPath), windowsRoot: URL(filePath: windowsRootPath))
        try Writer.updatePOTemplate(template: pot, entries: entries, destination: templateURL)
    }
}
