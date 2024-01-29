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
import OpenCC

@main
struct Translator: AsyncParsableCommand {
    @Argument
    var zhCNPath: String

    @Argument
    var zhTWPath: String

    func run() async throws {
        let converter = try ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom])
        let zhCNURL = URL(filePath: zhCNPath)
        let zhTWURL = URL(filePath: zhTWPath)
        let zhCNPO = try Parser.parsePO(at: zhCNURL)
        let zhTWPO = try Parser.parsePO(at: zhTWURL)
        try Writer.updatePO(po: zhTWPO, stringTransformer: { id, string in
            guard string.isEmpty else { return string }
            guard let match = zhCNPO.string(for: id) else { return string }
            return converter.convert(match)
        }, destination: zhTWURL)
    }
}
