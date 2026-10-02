import Foundation

enum MermaidExtractor {
    /// Returns every Mermaid diagram found in `text`: all ```mermaid fenced blocks
    /// if there are any, otherwise the whole text if it looks like a bare diagram.
    static func diagrams(in text: String) -> [String] {
        let fenced = fencedBlocks(in: text)
        if !fenced.isEmpty { return fenced }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return looksLikeMermaid(trimmed) ? [trimmed] : []
    }

    private static let fence = try! NSRegularExpression(
        pattern: #"^[ \t]*(`{3,}|~{3,})[ \t]*mermaid\b[^\n]*\n(.*?)^[ \t]*\1[ \t]*$"#,
        options: [.anchorsMatchLines, .dotMatchesLineSeparators, .caseInsensitive]
    )

    private static func fencedBlocks(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return fence.matches(in: text, range: range).compactMap { match in
            guard let body = Range(match.range(at: 2), in: text) else { return nil }
            let diagram = text[body].trimmingCharacters(in: .whitespacesAndNewlines)
            return diagram.isEmpty ? nil : diagram
        }
    }

    private static let diagramTypes: Set<String> = [
        "graph", "flowchart", "flowchart-elk", "sequencediagram", "classdiagram", "classdiagram-v2",
        "statediagram", "statediagram-v2", "erdiagram", "journey", "gantt", "pie", "quadrantchart",
        "requirementdiagram", "gitgraph", "c4context", "c4container", "c4component", "c4dynamic",
        "c4deployment", "mindmap", "timeline", "zenuml", "sankey", "sankey-beta", "xychart",
        "xychart-beta", "block", "block-beta", "packet", "packet-beta", "kanban", "architecture",
        "architecture-beta", "radar-beta", "treemap", "treemap-beta", "venn-beta", "info",
    ]

    /// Checks the first meaningful line (after optional YAML front matter and
    /// `%%` comments/directives) for a known Mermaid diagram keyword.
    private static func looksLikeMermaid(_ text: String) -> Bool {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)[...]

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            lines = lines.dropFirst()
            guard let end = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
                return false
            }
            lines = lines[(end + 1)...]
        }

        guard let first = lines
            .lazy
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty && !$0.hasPrefix("%%") })
        else { return false }

        let keyword = first.prefix { !$0.isWhitespace && $0 != ";" && $0 != ":" && $0 != "{" }
        return diagramTypes.contains(keyword.lowercased())
    }
}
