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
struct Updater: AsyncParsableCommand {
    @Argument
    var poPath: String

    @Argument
    var templatePath: String

    func run() async throws {
        let poURL = URL(filePath: poPath)
        let templateURL = URL(filePath: templatePath)
        let pot = try Parser.parsePOTemplate(at: templateURL)
        let po = try Parser.parsePO(at: poURL)
        try Writer.updatePO(po: po, template: pot, destination: poURL)
    }
}
