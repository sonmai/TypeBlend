import Foundation

// Keep proper names stable through partial composition and word boundaries.
private enum LiteralNames {
    static let words = Set(["zara"] + (UserDefaults.standard.stringArray(forKey: "LiteralNames") ?? []).map { $0.lowercased() })
    static let prefixes = Set(words.flatMap { word in word.indices.map { String(word[...$0]) } })
}

private struct Word {
    var raw = ""
    var engine = TelexEngine()
    var forced: String?
    var correctedRaw: String?
    init() { engine.liveSpellCheck = true }
    var live: String { forced ?? (LiteralNames.prefixes.contains(raw.lowercased()) ? raw : engine.composed) }
    mutating func add(_ c: Character) {
        forced = nil
        raw.append(c)
        _ = engine.feed(c)
        if raw == correctedRaw { forced = live }
    }
    var normal: String {
        var copy = engine
        return copy.commitText(autoRestore: true)
    }
}

struct Session {
    let model: Ranker
    var lookahead = true
    private var word = Word()
    private var pending: Word?
    private var pendingChoice = ""
    private var history: [String] = []
    init(_ model: Ranker) { self.model = model }
    var marked: String { (pending == nil ? "" : pendingChoice + " ") + word.live }
    var active: Bool { pending != nil || !word.raw.isEmpty }
    mutating func type(_ c: Character) { word.add(c) }

    private func choose(_ w: Word, next: String = "") -> String {
        if let forced = w.forced { return forced }
        if LiteralNames.words.contains(w.raw.lowercased()) { return w.raw }
        return model.choose(raw: w.raw, composed: w.engine.composed, fallback: w.normal,
                                 left: history, next: next)
    }
    private mutating func remember(_ text: String) {
        if !text.isEmpty { history.append(text) }
        if history.count > 12 { history.removeFirst() }
    }
    private mutating func settlePending() -> String {
        guard let p = pending else { return "" }
        let text = choose(p, next: word.normal)
        pending = nil
        remember(text)
        return text + " "
    }
    mutating func boundary(_ separator: String) -> String {
        var result = settlePending()
        let text = choose(word)
        if separator == " ", lookahead, model.supported.contains(word.raw.lowercased()),
           word.raw != word.engine.composed {
            pending = word
            pendingChoice = text
        } else {
            remember(text)
            result += text + separator
        }
        word = Word()
        return result
    }
    mutating func finish() -> String { boundary("") }
    mutating func forget() { history.removeAll() }
    mutating func backspace() -> Bool {
        if !word.raw.isEmpty {
            let original = word.correctedRaw ?? word.raw
            let rest = word.raw.dropLast()
            word = Word()
            word.correctedRaw = original
            for c in rest { word.add(c) }
        } else if let p = pending {
            word = p
            word.forced = p.forced ?? p.engine.composed
            word.correctedRaw = p.raw
            pending = nil
        } else { forget(); return false }
        return true
    }
    mutating func toggle() -> Bool {
        if word.raw.isEmpty, var p = pending {
            pendingChoice = pendingChoice == p.raw ? p.engine.composed : p.raw
            p.forced = pendingChoice
            pending = p
            return true
        }
        guard word.raw != word.engine.composed else { return false }
        word.forced = word.live == word.raw ? word.engine.composed : word.raw
        return true
    }
}
