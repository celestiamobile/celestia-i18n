//
// Parser.swift
//
// Copyright (C) 2024-present, Celestia Development Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.

import Foundation
import RegexBuilder

public enum Parser {
    enum Error: Swift.Error {
        case fileIO
        case fileEncoding
        case incorrectFileComment
        case `internal`(line: String)
        case unknownFlag(flag: String)
        case emptyFlag(line: String)
        case badReference(reference: String)
        case unknownContentType(line: String)
        case unknownLine(line: String)
        case contentTypeRedefined(type: String)
        case contentTypeMissing(type: String)
        case missingHeader
        case nonEmptyStringInTemplate
        case duplicateEntry(id: String, context: String?)
        case badContent(content: String)
    }

    struct Options: OptionSet {
        let rawValue: Int

        static let template = Options(rawValue: 1 << 0)
    }

    public static func parsePO(at url: URL) throws -> PO {
        return try parsePOFile(at: url, options: [])
    }

    public static func parsePOTemplate(at url: URL) throws -> PO.Template {
        return try parsePOFile(at: url, options: [.template])
    }

    private static func parsePOFile(at url: URL, options: Options) throws -> PO {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw Error.fileIO
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw Error.fileEncoding
        }

        var lines = string.split(separator: Regex {
            .newlineSequence
        })

        // Parsing file comments
        var commentLines = [String]()
        while var currentLine = lines.first?.trimmingCharacters(in: .whitespaces) {
            if currentLine.isEmpty {
                lines.removeFirst()
                continue
            }

            if !currentLine.starts(with: "#") {
                break
            }

            currentLine.trimPrefix(Regex {
                OneOrMore("#")
            })

            let lineContent: String
            if currentLine.isEmpty {
                lines.removeFirst()
                lineContent = ""
            } else if currentLine.first == " " {
                lines.removeFirst()
                lineContent = currentLine.trimmingCharacters(in: .whitespaces)
            } else {
                break
            }

            commentLines.append(lineContent)
        }
        let comment = commentLines.isEmpty ? nil : commentLines.joined(separator: "\n")

        func getNextEntry() throws -> PO.Entry {
            var references: [PO.Entry.Reference] = []
            var translatorComments: [String] = []
            var extractedComments: [String] = []
            var flags: PO.Entry.Flags = []
            var msgid: String?
            var msgctx: String?
            var msgstr: String?
            var previousContentType: ContentType?

            while let currentLine = lines.first?.trimmingCharacters(in: .whitespaces) {
                if currentLine.isEmpty {
                    lines.removeFirst()
                    continue
                }

                if let comment = try parseComment(line: currentLine) {

                    // Comments after content means this
                    // is a new entry
                    if previousContentType != nil {
                        break
                    }

                    switch comment {
                    case .translatorComment(let content):
                        translatorComments.append(content)
                    case .extractedComment(let content):
                        extractedComments.append(content)
                    case .flags(let flag):
                        flags.formUnion(flag)
                    case .references(let newRefs):
                        references.append(contentsOf: newRefs)
                    }
                    lines.removeFirst()
                    continue
                }

                if let content = try parseContent(line: currentLine) {
                    switch content.type {
                    case .msgid:
                        if msgid != nil {
                            throw Error.contentTypeRedefined(type: "msgid")
                        }
                        msgid = content.content
                    case .msgctx:
                        if msgctx != nil {
                            throw Error.contentTypeRedefined(type: "msgctx")
                        }
                        msgctx = content.content
                    case .msgstr:
                        if msgstr != nil {
                            throw Error.contentTypeRedefined(type: "msgstr")
                        }
                        msgstr = content.content
                    }
                    previousContentType = content.type
                    lines.removeFirst()
                    continue
                }

                if let additionalContent = try parseAdditionalContent(line: currentLine) {
                    guard let previousContentType else {
                        throw Error.unknownLine(line: currentLine)
                    }

                    switch previousContentType {
                    case .msgid:
                        msgid = (msgid ?? "").appending(additionalContent)
                    case .msgctx:
                        msgctx = (msgctx ?? "").appending(additionalContent)
                    case .msgstr:
                        msgstr = (msgstr ?? "").appending(additionalContent)
                    }
                    lines.removeFirst()
                    continue
                }

                throw Error.unknownLine(line: currentLine)
            }

            guard let msgid else {
                throw Error.contentTypeMissing(type: "msgid")
            }

            guard let msgstr else {
                throw Error.contentTypeMissing(type: "msgstr")
            }

            return PO.Entry(translatorComments: translatorComments, extractedComments: extractedComments, references: references, flags: flags, id: msgid, string: msgstr, context: msgctx)
        }

        // Header is the first entry
        let header = try getNextEntry()
        guard header.id == "" else {
            throw Error.missingHeader
        }

        var entries = [PO.Entry]()
        while !lines.isEmpty {
            let entry = try getNextEntry()

            if options.contains(.template), !entry.string.isEmpty {
                throw Error.nonEmptyStringInTemplate
            }

            entries.append(entry)
        }

        try entries.sort { entry0, entry1 in
            switch entry0.id.localizedStandardCompare(entry1.id) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                if let context0 = entry0.context, let context1 = entry1.context {
                    switch context0.localizedStandardCompare(context1) {
                    case .orderedAscending:
                        return true
                    case .orderedDescending:
                        return false
                    case .orderedSame:
                        throw Error.duplicateEntry(id: entry0.id, context: context0)
                    }
                } else if entry0.context != nil {
                    return true
                } else if entry1.context != nil {
                    return false
                } else {
                    throw Error.duplicateEntry(id: entry0.id, context: nil)
                }
            }
        }

        return PO(comment: comment, header: header, entries: entries)
    }

    enum Comment {
        case translatorComment(content: String)
        case extractedComment(content: String)
        case flags(flag: PO.Entry.Flags)
        case references(references: [PO.Entry.Reference])
    }

    private static func parseComment(line: String) throws -> Comment? {
        let typeRef = Reference(TypeCharacter?.self)
        let contentRef = Reference(Substring.self)

        enum TypeCharacter: String {
            case translatorComments = " "
            case extractedComments = "."
            case references = ":"
            case flags = ","
        }

        let entryCommentRegex = Regex {
            One("#")
            Capture(as: typeRef) {
                ChoiceOf {
                    " "
                    "."
                    ":"
                    ","
                }
            } transform: {
                TypeCharacter(rawValue: String($0))
            }
            ZeroOrMore(.whitespace)
            Capture(as: contentRef) {
                OneOrMore(.any)
            }
        }

        if let matchedComment = line.wholeMatch(of: entryCommentRegex) {
            guard let type = matchedComment[typeRef] else {
                throw Error.`internal`(line: String(line))
            }
            let content = matchedComment[contentRef]

            enum FlagCharacters: String {
                case cFormat = "c-format"
                case fuzzy = "fuzzy"

                var flag: PO.Entry.Flags {
                    switch self {
                    case .cFormat:
                        return .cFormat
                    case .fuzzy:
                        return .fuzzy
                    }
                }
            }

            switch type {
            case .extractedComments:
                return .extractedComment(content: String(content))
            case .translatorComments:
                return .translatorComment(content: String(content))
            case .flags:
                var flags: PO.Entry.Flags = []
                let flagComponents = content.split(separator: Regex {
                    ","
                    ZeroOrMore {
                        .whitespace
                    }
                })
                if flagComponents.isEmpty {
                    throw Error.emptyFlag(line: line)
                }
                for flagComponent in flagComponents {
                    let flagRef = Reference(FlagCharacters?.self)
                    guard let match = flagComponent.wholeMatch(of: Regex {
                        Capture(as: flagRef) {
                            ChoiceOf {
                                "c-format"
                                "fuzzy"
                            }
                        } transform: {
                            FlagCharacters(rawValue: String($0))
                        }
                    }), let flag = match[flagRef] else {
                        throw Error.unknownFlag(flag: String(flagComponent))
                    }
                    flags.formUnion(flag.flag)
                }
                return .flags(flag: flags)
            case .references:
                var references: [PO.Entry.Reference] = []
                let referenceComponents = content.split(separator: Regex {
                    ZeroOrMore {
                        .whitespace
                    }
                })
                for referenceComponent in referenceComponents {
                    let pathRef = Reference(Substring.self)
                    let lineNumberRef = Reference(Int?.self)
                    let hasLineNumberRegex = Regex {
                        Capture(as: pathRef) {
                            OneOrMore(.any)
                        }
                        ":"
                        Capture {
                            OneOrMore(.digit)
                        } transform: {
                            Int(String($0))
                        }
                    }
                    if let match = referenceComponent.wholeMatch(of: hasLineNumberRegex) {
                        guard let lineNumber = match[lineNumberRef] else {
                            throw Error.badReference(reference: String(referenceComponent))
                        }
                        references.append(PO.Entry.Reference(sourceFilePath: String(match[pathRef]), lineNumber: lineNumber))
                    } else {
                        references.append(PO.Entry.Reference(sourceFilePath: String(referenceComponent), lineNumber: nil))
                    }
                }
                return .references(references: references)
            }
        } else {
            return nil
        }
    }

    enum ContentType: String {
        case msgid
        case msgctx
        case msgstr
    }

    struct Content {
        let type: ContentType
        let content: String
    }

    private static func parseContent(line: String) throws -> Content? {
        let typeRef = Reference(ContentType?.self)
        let contentRef = Reference(Substring.self)
        let regex = Regex {
            Capture(as: typeRef) {
                ChoiceOf {
                    "msgid"
                    "msgctx"
                    "msgstr"
                }
            } transform: {
                ContentType(rawValue: String($0))
            }
            ZeroOrMore { .whitespace }
            "\""
            Capture(as: contentRef) {
                ZeroOrMore { .any }
            }
            "\""
        }

        guard let match = line.wholeMatch(of: regex) else {
            return nil
        }

        guard let type = match[typeRef] else {
            throw Error.unknownContentType(line: line)
        }

        let value = String(match[contentRef])
        guard let unescaped = value.unescaped else {
            throw Error.badContent(content: value)
        }

        return Content(type: type, content: unescaped)
    }

    private static func parseAdditionalContent(line: String) throws -> String? {
        let contentRef = Reference(Substring.self)
        let regex = Regex {
            ZeroOrMore { .whitespace }
            "\""
            Capture(as: contentRef) {
                ZeroOrMore { .any }
            }
            "\""
        }

        guard let match = line.wholeMatch(of: regex) else {
            return nil
        }

        let value = String(match[contentRef])
        guard let unescaped = value.unescaped else {
            throw Error.badContent(content: value)
        }

        return unescaped
    }
}
