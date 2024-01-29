//
// Extractor.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import Foundation
import RegexBuilder

public enum Extractor {
    enum Error: Swift.Error {
        case enumeration
        case fileIO
        case fileEncoding
        case badContent(content: String)
    }

    private struct Platforms: OptionSet {
        let rawValue: Int

        static let apple = Platforms(rawValue: 1 << 0)
        static let android = Platforms(rawValue: 1 << 1)
        static let windows = Platforms(rawValue: 1 << 2)
    }

    private struct Identifier: Hashable {
        let id: String
        let context: String?
    }

    private struct EntryInformation {
        let entry: PO.Entry
        var platforms: Platforms
    }

    public static func extractStrings(appleRoot: URL, androidRoot: URL, windowsRoot: URL) throws -> [PO.Entry] {
        let appleEntries = try extractStrings(at: appleRoot)
        let androidEntries = try extractStrings(at: androidRoot)
        let windowsEntries = try extractStrings(at: windowsRoot)

        var results: [Identifier: EntryInformation] = [:]

        func mergeEntries(entry0: PO.Entry, entry1: PO.Entry) -> PO.Entry {
            return PO.Entry(
                translatorComments: Array(Set(entry0.translatorComments + entry1.translatorComments)).sorted(by: <),
                extractedComments: Array(Set(entry0.extractedComments + entry1.extractedComments)).sorted(by: <),
                references: Array(Set(entry0.references + entry1.references)).sorted(by: { ref0, ref1 in
                    switch ref0.sourceFilePath.localizedStandardCompare(ref1.sourceFilePath) {
                    case .orderedAscending:
                        return true
                    case .orderedDescending:
                        return false
                    case .orderedSame:
                        if let line0 = ref0.lineNumber, let line1 = ref1.lineNumber {
                            return line0 < line1
                        } else if ref0.lineNumber != nil {
                            return false
                        } else if ref1.lineNumber != nil {
                            return true
                        } else {
                            return false
                        }
                    }
                }),
                flags: entry0.flags.union(entry1.flags),
                id: entry0.id,
                string: entry0.string,
                context: entry0.context
            )
        }

        func addEntry(entry: PO.Entry, platform: Platforms) throws {
            let identifier = Identifier(id: entry.id, context: entry.context)

            if let existing = results[identifier] {
                results[identifier] = EntryInformation(entry: mergeEntries(entry0: existing.entry, entry1: entry), platforms: existing.platforms.union(platform))
            } else {
                results[identifier] = EntryInformation(entry: entry, platforms: platform)
            }
        }

        for appleEntry in appleEntries {
            try addEntry(entry: appleEntry, platform: .apple)
        }

        for androidEntry in androidEntries {
            try addEntry(entry: androidEntry, platform: .android)
        }

        for windowsEntry in windowsEntries {
            try addEntry(entry: windowsEntry, platform: .windows)
        }

        return results.sorted(by: { item0, item1 in
            let id0 = item0.key.id
            let context0 = item0.key.context
            let id1 = item1.key.id
            let context1 = item1.key.context
            switch id0.localizedStandardCompare(id1) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                if let context0, let context1 {
                    switch context0.localizedStandardCompare(context1) {
                    case .orderedAscending:
                        return true
                    case .orderedDescending:
                        return false
                    case .orderedSame:
                        return true
                    }
                } else if context0 != nil {
                    return false
                } else if context1 != nil {
                    return true
                } else {
                    return false
                }
            }
        }).map { item in
            var platformStrings: [String] = []
            let platforms = item.value.platforms
            let entry = item.value.entry
            if platforms.contains(.apple) {
                platformStrings.append("Apple")
            }
            if platforms.contains(.android) {
                platformStrings.append("Android")
            }
            if platforms.contains(.windows) {
                platformStrings.append("Windows")
            }

            return PO.Entry(
                translatorComments: ["Platforms: \(platformStrings.joined(separator: ", "))"] + entry.translatorComments,
                extractedComments: entry.extractedComments,
                references: entry.references,
                flags: entry.flags,
                id: entry.id,
                string: entry.string,
                context: entry.context
            )
        }
    }

    private static func extractStrings(at directoryURL: URL) throws -> [PO.Entry] {
        let fm = FileManager.default
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            throw Error.enumeration
        }
        var entries: [PO.Entry] = []
        for content in contents {
            let isDirectory: Bool
            do {
                isDirectory = try content.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
            } catch {
                throw Error.fileIO
            }
            if isDirectory {
                try entries.append(contentsOf: extractStrings(at: content))
            } else {
                try entries.append(contentsOf: extractStrings(from: content))
            }
        }
        return entries
    }

    enum FileType: String {
        case cpp = "cpp"
        case cs = "cs"
        case swift = "swift"
        case kotlin = "kt"

        var twoArgumentTemplate: Regex<(Substring, Substring, Substring)> {
            switch self {
            case .cpp:
                #/LocalizationHelper\s*::\s*Localize\s*\(\s*L"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*L"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .cs:
                #/LocalizationHelper\s*\.\s*Localize\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .swift:
                #/CelestiaString\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*comment\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .kotlin:
                #/CelestiaString\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            }
        }

        var threeArgumentTemplate: Regex<(Substring, Substring, Substring, Substring)> {
            switch self {
            case .cpp:
                #/LocalizationHelper\s*::\s*Localize\s*\(\s*L"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*L"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*L"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .cs:
                #/LocalizationHelper\s*\.\s*Localize\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .swift:
                #/CelestiaString\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*context\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\,\s*comment\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            case .kotlin:
                #/CelestiaString\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/#
            }
        }
    }

    private static func extractStrings(from fileURL: URL) throws -> [PO.Entry] {
        guard let type = FileType(rawValue: fileURL.pathExtension) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw Error.fileIO
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw Error.fileEncoding
        }

        let specifierRegex = #/\%[0 #+-]?[0-9*]*\.?\d*[hl]{0,2}[jztL]?[diuoxXeEfgGaAcpsSn%@]/#
        func createEntry(id: String, context: String?, comment: String) throws -> PO.Entry {
            guard let unescapedId = id.unescaped else {
                throw Error.badContent(content: id)
            }
            guard let unescapedComment = comment.unescaped else {
                throw Error.badContent(content: comment)
            }
            var unescapedContext: String?
            if let context {
                guard let unescaped = context.unescaped else {
                    throw Error.badContent(content: context)
                }
                unescapedContext = unescaped
            }

            var flags: PO.Entry.Flags = []
            if unescapedId.contains(specifierRegex) {
                flags.formUnion(.cFormat)
            }

            return PO.Entry(translatorComments: unescapedComment.isEmpty ? [] : [unescapedComment], extractedComments: [], references: [], flags: flags, id: unescapedId, string: "", context: unescapedContext)
        }

        var entries: [PO.Entry] = []
        for match in content.matches(of: type.twoArgumentTemplate) {
            try entries.append(createEntry(id: String(match.1), context: nil, comment: String(match.2)))
        }

        for match in content.matches(of: type.threeArgumentTemplate) {
            try entries.append(createEntry(id: String(match.1), context: String(match.2), comment: String(match.3)))
        }

        return entries
    }
}
