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
struct Formatter: AsyncParsableCommand {
    @Argument
    var potPath: String

    func run() async throws {
        let url = URL(filePath: potPath)
        let pot = try Parser.parsePOTemplate(at: url)
        try Writer.writePOTemplate(template: pot, destination: url)
    }
}
