//
// String.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import Foundation
import RegexBuilder

extension String {
    var unescaped: String? {
        // TODO: Check validity
        let entities: [(original: String, escaped: String)] = [
            ("\0", "\\0"),
            ("\t", "\\t"),
            ("\n", "\\n"),
            ("\r", "\\r"),
            ("\"", "\\\""),
            ("\\", "\\\\"),
        ]

        var current = self
        for match in current.matches(of: #/\\u([0-9a-fA-F]{4})/#).reversed() {
            let substring = match.1
            guard let value = UInt32(String(substring), radix: 16) else {
                return nil
            }
            guard let scalar = UnicodeScalar(value) else {
                return nil
            }
            let character = Character(scalar)
            current.replaceSubrange(match.range, with: [character])
        }

        for (original, escaped) in entities {
            current = current.replacingOccurrences(of: escaped, with: original)
        }
        return current
    }

    func escaped(asciiOnly: Bool) -> String {
        let entities: [(original: String, escaped: String)] = [
            ("\0", "\\0"),
            ("\t", "\\t"),
            ("\n", "\\n"),
            ("\r", "\\r"),
            ("\"", "\\\""),
            ("\\", "\\\\"),
        ]
        var current = self
        for (original, escaped) in entities.reversed() {
            current = current.replacingOccurrences(of: original, with: escaped)
        }
        if !asciiOnly {
            return current
        }
        var endIndex = current.endIndex
        while let lastIndex = current[current.startIndex..<endIndex].lastIndex(where: { character in
            return !character.isASCII
        }) {
            let character = current[lastIndex]
            let unicodeValue = character.unicodeScalars[character.unicodeScalars.startIndex].value
            current.replaceSubrange(lastIndex..<current.index(lastIndex, offsetBy: 1), with: String(format: "\\b%04x", unicodeValue))
            endIndex = lastIndex
        }
        return current
    }
}
