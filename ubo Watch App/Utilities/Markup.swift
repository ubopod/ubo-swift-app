//
//  Markup.swift
//  ubo Watch App
//
//  watchOS counterpart of the iOS `markupText` helper. Renders Kivy /
//  BBCode-style tags ([b], [i], [u], [color=#hex]) as a styled SwiftUI
//  `Text`, mirroring what the GUI client paints on the Pi screen.
//

import SwiftUI

public func markupText(_ raw: String) -> Text {
    guard raw.contains("[") else { return Text(raw) }
    var out = Text(verbatim: "")
    for s in parseMarkupSegments(raw) {
        var t = Text(verbatim: s.text)
        if s.bold { t = t.bold() }
        if s.italic { t = t.italic() }
        if s.underline { t = t.underline() }
        if let c = s.color { t = t.foregroundColor(c) }
        out = out + t
    }
    return out
}

public func stripMarkup(_ raw: String) -> String {
    guard raw.contains("[") else { return raw }
    return raw.replacingOccurrences(
        of: #"\[/?(?:b|i|u|color|size|ref|anchor)(?:=[^\]]*)?\]"#,
        with: "",
        options: .regularExpression
    )
}

private struct MarkupSegment {
    var text: String = ""
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var color: Color?
}

private let markupTagPattern = #"\[(/?)([a-zA-Z]+)(?:=([^\]]+))?\]"#

private func parseMarkupSegments(_ raw: String) -> [MarkupSegment] {
    guard let regex = try? NSRegularExpression(pattern: markupTagPattern) else {
        return [MarkupSegment(text: raw)]
    }
    let ns = raw as NSString
    let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))

    let recognised: Set<String> = ["b", "i", "u", "color", "size"]
    var segments: [MarkupSegment] = []
    var stack: [MarkupSegment] = [MarkupSegment()]
    var cursor = 0

    for match in matches {
        let r = match.range
        if r.location > cursor {
            var seg = stack.last!
            seg.text = ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
            segments.append(seg)
        }
        cursor = r.location + r.length

        let tag = ns.substring(with: match.range(at: 2)).lowercased()
        guard recognised.contains(tag) else { continue }

        let isClosing = ns.substring(with: match.range(at: 1)) == "/"
        if isClosing {
            if stack.count > 1 { stack.removeLast() }
            continue
        }

        var top = stack.last!
        switch tag {
        case "b": top.bold = true
        case "i": top.italic = true
        case "u": top.underline = true
        case "color":
            if match.range(at: 3).location != NSNotFound,
               let c = Color(hex: ns.substring(with: match.range(at: 3))) {
                top.color = c
            }
        case "size":
            break
        default:
            break
        }
        stack.append(top)
    }

    if cursor < ns.length {
        var seg = stack.last!
        seg.text = ns.substring(from: cursor)
        segments.append(seg)
    }
    return segments
}
