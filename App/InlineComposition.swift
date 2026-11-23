import Foundation

// Track only text we inserted. A selection change or an external edit ends ownership.
struct InlineComposition {
    private var start = 0
    private var visible = ""

    private static let inlineClients: Set<String> = [
        "com.apple.notes", "com.openai.chat", "com.openai.chatgpt", "com.openai.codex",
        "com.microsoft.vscode", "com.microsoft.vscodeinsiders",
        "com.apple.safari", "com.apple.safaritechnologypreview",
        "com.google.chrome", "com.google.chrome.beta", "com.google.chrome.dev",
        "com.google.chrome.canary", "org.chromium.chromium",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly",
        "com.microsoft.edgemac", "com.brave.browser", "company.thebrowser.browser",
    ]

    static func enabled(in bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return inlineClients.contains(bundleID.lowercased())
    }

    enum Status { case ready, moved, unavailable }

    func status(_ selection: NSRange, read: (NSRange) -> String?) -> Status {
        guard selection.location != NSNotFound else { return .unavailable }
        guard !visible.isEmpty else { return .ready }
        let length = visible.utf16.count
        guard selection == NSRange(location: start + length, length: 0) else { return .moved }
        guard let actual = read(NSRange(location: start, length: length)) else { return .unavailable }
        return actual.utf16.elementsEqual(visible.utf16) ? .ready : .moved
    }

    mutating func display(committed: String, composing: String, selection: NSRange,
                          bufferWord: Bool = false, insert: (String, NSRange) -> Void) {
        let selectionRange = NSRange(location: NSNotFound, length: 0)
        if bufferWord {
            if !committed.isEmpty { insert(committed, selectionRange) }
            return
        }
        let updated = committed + composing
        if visible.isEmpty {
            if !updated.isEmpty { insert(updated, selectionRange) }
            start = selection.location
        } else {
            let prefix = zip(visible, updated).prefix { $0 == $1 }.count
            let offset = visible.prefix(prefix).utf16.count
            let range = NSRange(location: start + offset, length: visible.utf16.count - offset)
            let suffix = String(updated.dropFirst(prefix))
            if range.length > 0 || !suffix.isEmpty {
                insert(suffix, range.length == 0 ? selectionRange : range)
            }
        }
        guard start != NSNotFound else { visible = ""; return }
        start += committed.utf16.count
        visible = composing
    }
}
