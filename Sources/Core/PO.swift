//
// PO.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import Foundation

// Representing a PO file
public struct PO {
    // Representing an entry in PO file
    public struct Entry {
        public struct Reference: Hashable {
            let sourceFilePath: String
            let lineNumber: Int?
        }

        public struct Flags: OptionSet {
            public let rawValue: Int

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let cFormat = Flags(rawValue: 1 << 0)
            public static let fuzzy = Flags(rawValue: 1 << 1)
            public static let cppFormat = Flags(rawValue: 1 << 2)
            public static let qtFormat = Flags(rawValue: 1 << 3)
        }

        let translatorComments: [String]
        let extractedComments: [String]
        let references: [Reference]
        let flags: Flags

        let id: String
        let string: String
        let context: String?
    }

    public typealias Template = PO

    let comment: String?
    let header: Entry
    let entries: [Entry]
}

public extension PO {
    func string(for id: String) -> String? {
        return entries.first(where: { $0.id == id })?.string
    }
}
