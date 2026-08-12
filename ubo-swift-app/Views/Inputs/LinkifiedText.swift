//
//  LinkifiedText.swift
//  ubo-swift-app
//
//  Renders text with any URLs in it as real, tappable links — the native
//  counterpart to the Web UI's `LinkifiedText` (ubo_app/services/090-web-ui/
//  web-app/src/inputs.tsx). Input prompts/subtitles routinely carry a page
//  the user has to visit (e.g. an OAuth authorization URL a few hundred
//  characters long with PKCE state); shown as plain text that's either
//  unreadable or, worse, gets shoved into a single-line title and
//  truncated. `Text(AttributedString)` with a `.link` run lets SwiftUI open
//  it with the system's normal link-tap handling, no custom gesture code.
//

import SwiftUI

struct LinkifiedText: View {
    let text: String
    var font: Font = .body
    var color: Color = .secondary

    private static let urlPattern = try? NSRegularExpression(pattern: #"https?://\S+"#)
    // Beyond this, a URL stops being readable and starts wrecking the layout.
    private static let maxLinkTextLength = 48

    var body: some View {
        Text(attributedString)
            .font(font)
            .foregroundStyle(color)
    }

    private var attributedString: AttributedString {
        guard let regex = Self.urlPattern else { return AttributedString(text) }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return AttributedString(text) }

        var result = AttributedString()
        var lastEnd = 0
        for match in matches {
            let range = match.range
            if range.location > lastEnd {
                result += AttributedString(nsText.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd)))
            }
            let urlString = nsText.substring(with: range)
            var link = AttributedString(Self.shortened(urlString))
            link.link = URL(string: urlString)
            result += link
            lastEnd = range.location + range.length
        }
        if lastEnd < nsText.length {
            result += AttributedString(nsText.substring(from: lastEnd))
        }
        return result
    }

    /// OAuth authorization URLs run to several hundred characters of PKCE
    /// challenge and state, so the visible text is shortened to host + path
    /// while the link target keeps the whole thing.
    private static func shortened(_ url: String) -> String {
        guard url.count > maxLinkTextLength else { return url }
        if let parsed = URL(string: url), let host = parsed.host {
            let short = host + parsed.path
            if short.count <= maxLinkTextLength { return short + "…" }
            return host + "…"
        }
        return String(url.prefix(maxLinkTextLength)) + "…"
    }
}
