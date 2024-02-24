//
// Writer.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import Foundation

public enum Writer {
    enum Error: Swift.Error {
        case dataConversion
        case fileIO
    }

    public struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let withoutOverwriting = Options(rawValue: 1 << 0)
    }

    public static func updatePOTemplate(template: PO.Template, entries: [PO.Entry], options: Options = [], destination: URL) throws {
        let newTemplate = PO.Template(comment: template.comment, header: template.header, entries: entries)
        try _writePO(po: newTemplate, stringProvider: nil, options: options, destination: destination)
    }

    public static func updatePO(po: PO, template: PO.Template, options: Options = [], destination: URL) throws {
        try _writePO(po: template, stringProvider: po, options: options, destination: destination)
    }

    public static func writePOTemplate(template: PO.Template, options: Options = [], destination: URL) throws {
        try _writePO(po: template, stringProvider: nil, options: options, destination: destination)
    }

    private static func _writePO(po: PO, stringProvider: PO?, options: Options, destination: URL) throws {
        var parts: [String] = []
        if let comment = po.comment {
            let joinedComponents = comment.components(separatedBy: "\n").map({ ("# " + $0).trimmingCharacters(in: .whitespaces) }).joined(separator: "\n")
            parts.append(joinedComponents)
        }

        func formatEntry(entry: PO.Entry, maxLineWidth: Int?, overrideString: String?) -> String {
            var parts: [String] = []
            for translatorComment in entry.translatorComments {
                parts.append("#  \(translatorComment)")
            }
            for extractedComment in entry.extractedComments {
                parts.append("#. \(extractedComment)")
            }
            for reference in entry.references {
                if let lineNumber = reference.lineNumber {
                    parts.append("#: \(reference.sourceFilePath):\(lineNumber)")
                } else {
                    parts.append("#: \(reference.sourceFilePath)")
                }
            }
            if !entry.flags.isEmpty {
                var flagParts = [String]()
                if entry.flags.contains(.cFormat) {
                    flagParts.append("c-format")
                }
                if entry.flags.contains(.cppFormat) {
                    flagParts.append("c++-format")
                }
                if entry.flags.contains(.qtFormat) {
                    flagParts.append("qt-format")
                }
                if entry.flags.contains(.fuzzy) {
                    flagParts.append("fuzzy")
                }
                parts.append("#, \(flagParts.joined(separator: ", "))")
            }

            func formatContent(content: String, maxLineWidth: Int?) -> String {
                var parts: [String] = []
                var lines = content.components(separatedBy: "\n")
                let addEmptyLine: Bool
                if lines.count > 1 {
                    addEmptyLine = true
                } else if let maxLineWidth, lines[0].count > maxLineWidth {
                    addEmptyLine = true
                } else {
                    addEmptyLine = false
                }
                if addEmptyLine {
                    parts.append("")
                }
                let originalLineCount = lines.count
                if lines.count > 1 && lines[lines.count - 1].isEmpty {
                    lines.removeLast()
                }
                for (index, line) in lines.enumerated() {
                    if let maxLineWidth, line.count > maxLineWidth {
                        var current = Substring(line)
                        while current.count > maxLineWidth, let lastSpaceIndex = current[..<current.index(current.startIndex, offsetBy: maxLineWidth)].lastIndex(of: " ") {
                            parts.append(String(current[...lastSpaceIndex]))
                            current = current[current.index(lastSpaceIndex, offsetBy: 1)...]
                        }
                        if index != originalLineCount - 1 {
                            parts.append(String(current) + "\n")
                        } else {
                            parts.append(String(current))
                        }
                    } else {
                        if index != originalLineCount - 1 {
                            parts.append(line + "\n")
                        } else {
                            parts.append(line)
                        }
                    }
                }
                return parts.map({ "\"\($0.escaped(asciiOnly: false))\"" }).joined(separator: "\n")
            }

            if let context = entry.context {
                parts.append("msgctxt \(formatContent(content: context, maxLineWidth: maxLineWidth))")
            }
            parts.append("msgid \(formatContent(content: entry.id, maxLineWidth: maxLineWidth))")
            parts.append("msgstr \(formatContent(content: overrideString ?? entry.string, maxLineWidth: maxLineWidth))")
            return parts.joined(separator: "\n")
        }

        parts.append(formatEntry(entry: po.header, maxLineWidth: nil, overrideString: stringProvider?.header.string))

        for entry in po.entries {
            parts.append(formatEntry(entry: entry, maxLineWidth: 50, overrideString: stringProvider?.entries.first(where: { $0.id == entry.id })?.string))
        }

        let string = parts.joined(separator: "\n\n")
        guard let data = string.data(using: .utf8) else {
            throw Error.dataConversion
        }

        do {
            try data.write(to: destination, options: options.contains(.withoutOverwriting) ? .withoutOverwriting : [])
        } catch {
            throw Error.fileIO
        }
    }
}
