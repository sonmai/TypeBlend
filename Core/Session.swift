import Foundation

private struct Word {
    var raw = ""
    var engine = TelexEngine()
    var forced: String?
    var explicitCorrection = false
    var correctedRaw: String?
    init() { engine.liveSpellCheck = true }
    var composed: String { engine.isOverflowed ? raw : engine.composed }
    var live: String { forced ?? composed }
    mutating func add(_ c: Character, preferences: TypingPreferences) {
        forced = nil
        explicitCorrection = false
        raw.append(c)
        _ = engine.feed(c)
        if raw == correctedRaw { forced = preferences.prefix(raw) ? raw : live }
    }
    func normal(before boundary: Character? = nil) -> String {
        if engine.isOverflowed { return raw }
        return engine.peekCommitText(autoRestore: true, boundary: boundary)
    }
}

struct Session {
    let model: Ranker
    var lookahead = true
    private var word = Word()
    private var pending: Word?
    private var pendingChoice = ""
    private var history: [String] = []
    private let preferences: TypingPreferences
    private var live: String { word.forced ?? (preferences.prefix(word.raw) ? word.raw : word.live) }
    struct Recent {
        let raw, composed, separator: String
        let key: String?
        var choice: String
        var corrected: Bool
        func range(at selection: NSRange, expectedCaret: NSRange?, read: (NSRange) -> String?) -> NSRange? {
            let expected = choice + separator
            let length = expected.utf16.count
            guard selection == expectedCaret, selection.length == 0, selection.location != NSNotFound,
                  selection.location >= length else { return nil }
            let range = NSRange(location: selection.location - length, length: length)
            return read(range)?.utf16.elementsEqual(expected.utf16) == true ? range : nil
        }
    }
    private(set) var recent: Recent?
    init(_ model: Ranker, preferences: TypingPreferences = .shared) {
        self.model = model
        self.preferences = preferences
    }
    private func contextKey(_ raw: String) -> String? {
        guard !history.isEmpty else { return nil }
        return history.suffix(2).joined(separator: " ").lowercased() + "|" + raw.lowercased()
    }
    private mutating func finishRecent() {
        if let r = recent, r.corrected { preferences.record(r.key, raw: r.choice == r.raw) }
        recent = nil
    }
    mutating func correctRecent(pin: Bool) {
        guard var r = recent else { return }
        if pin { preferences.pin(r.raw) }
        r.choice = pin || r.choice != r.raw ? r.raw : r.composed
        r.corrected = !pin
        recent = r
        if !history.isEmpty { history[history.count - 1] = r.choice }
    }
    mutating func pinCurrent() -> Bool {
        if !word.raw.isEmpty { preferences.pin(word.raw); word.forced = word.raw; return true }
        if var p = pending {
            preferences.pin(p.raw); p.forced = p.raw; pending = p; pendingChoice = p.raw
            return true
        }
        return false
    }
    var marked: String { (pending == nil ? "" : pendingChoice + " ") + live }
    var active: Bool { pending != nil || !word.raw.isEmpty }
    mutating func type(_ c: Character) { finishRecent(); word.add(c, preferences: preferences) }

    private func choose(_ w: Word, next: String = "", boundary: Character? = nil) -> String {
        if let forced = w.forced { return forced }
        if preferences.literal(w.raw) { return w.raw }
        if w.raw != w.composed, let raw = preferences.preference(contextKey(w.raw)) {
            return raw ? w.raw : w.composed
        }
        return model.choose(raw: w.raw, composed: w.composed, fallback: w.normal(before: boundary),
                                 left: history, next: next)
    }
    private mutating func remember(_ text: String) {
        if !text.isEmpty { history.append(text) }
        if history.count > 12 { history.removeFirst() }
    }
    private mutating func settlePending(before boundary: Character?) -> String {
        guard let p = pending else { return "" }
        let text = choose(p, next: word.normal(before: boundary), boundary: " ")
        if p.explicitCorrection { preferences.record(contextKey(p.raw), raw: text == p.raw) }
        pending = nil
        remember(text)
        return text + " "
    }
    mutating func boundary(_ separator: String) -> String {
        finishRecent()
        var result = settlePending(before: separator.first)
        let text = choose(word, boundary: separator.first)
        if separator == " ", lookahead, model.supported.contains(word.raw.lowercased()),
           word.raw != word.composed {
            pending = word
            pendingChoice = text
        } else {
            if !separator.isEmpty, !word.raw.isEmpty {
                recent = Recent(raw: word.raw, composed: word.composed, separator: separator,
                                key: contextKey(word.raw), choice: text, corrected: word.explicitCorrection)
            } else if word.explicitCorrection { preferences.record(contextKey(word.raw), raw: text == word.raw) }
            remember(text)
            result += text + separator
        }
        word = Word()
        return result
    }
    mutating func finish() -> String { boundary("") }
    mutating func forget() { finishRecent(); history.removeAll() }
    mutating func backspace() -> Bool {
        if !word.raw.isEmpty {
            let original = word.correctedRaw ?? word.raw
            let rest = word.raw.dropLast()
            word = Word()
            word.correctedRaw = original
            for c in rest { word.add(c, preferences: preferences) }
        } else if let p = pending {
            word = p
            word.forced = p.forced ?? p.composed
            word.correctedRaw = p.raw
            pending = nil
        } else { forget(); return false }
        return true
    }
    mutating func toggle() -> Bool {
        if word.raw.isEmpty, var p = pending {
            pendingChoice = pendingChoice == p.raw ? p.composed : p.raw
            p.explicitCorrection = true
            p.forced = pendingChoice
            pending = p
            return true
        }
        guard word.raw != word.composed else { return false }
        word.explicitCorrection = true
        word.forced = live == word.raw ? word.composed : word.raw
        return true
    }
}
