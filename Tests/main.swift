import Foundation

let model = try Ranker(URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent())
let suite = "TypeBlendTests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
let preferences = TypingPreferences(defaults)
func replay(_ keys: String) -> String {
    var session = Session(model, preferences: preferences)
    var output = ""
    for c in keys {
        if c == "⌫" { _ = session.backspace() }
        else if c == "⇄" { precondition(session.toggle()) }
        else if c.isLetter { session.type(c) }
        else { output += session.boundary(String(c)) }
    }
    return output + session.finish()
}
var brand = Session(model, preferences: preferences)
var prefix = ""
for c in "Zara" {
    prefix.append(c)
    brand.type(c)
    precondition(brand.marked == prefix)
}
for length in [32, 33, 40] {
    let token = String(repeating: "b", count: length)
    var session = Session(model, preferences: preferences)
    for c in token { session.type(c) }
    precondition(session.marked == token)
    precondition(session.backspace() && session.marked == String(token.dropLast()))
    session.type("b")
    precondition(session.boundary(" ") == token + " ")
}
for newline in ["\n", "\r\n"] {
    precondition(Ranker.entries("out of office" + newline + "proof of concept" + newline)
                 == ["out of office", "proof of concept"])
}
precondition(model.englishPhrases.contains("out of office") && model.supported.contains("barns"))
let cases = [
    ("doesn't isn't won't", "doesn't isn't won't"),
    ("doesn’t isn’t won’t", "doesn’t isn’t won’t"),
    ("mai minhf out of office.", "mai mình out of office."),
    ("guwir proof of concept nhes", "gửi proof of concept nhé"),
    ("zara", "zara"),
    ("Zara, ZARA!", "Zara, ZARA!"),
    ("zara⌫a ", "zara "),
    ("tooi mua Zara hoom qua", "tôi mua Zara hôm qua"),
    ("Tooi muoosn gox of", "Tôi muốn gõ ò"),
    ("of ", "ò "),
    ("kind of work", "kind of work"),
    ("kind of ⌫ ", "kind ò "),
    ("kind of ⌫⌫f work", "kind ò work"),
    ("of ⇄", "of "),
    ("Guwir minhf file gif nhes", "Gửi mình file gif nhé"),
    ("Banj vuwaf guwir minhf file gif vaayj?", "Bạn vừa gửi mình file gì vậy?"),
    ("DDawtj max laf 10 rooif nhaapj max mowis", "Đặt max là 10 rồi nhập mã mới"),
    ("Giowsi hanj upload. DDawtj max laf 10.", "Giới hạn upload. Đặt max là 10."),
    ("Max truy caapj. DDawtj max laf 10.", "Mã truy cập. Đặt mã là 10."),
    ("Banj caanf gif nuwax?", "Bạn cần gì nữa?"),
    ("Guwir cho tooi report.", "Gửi cho tôi report."),
    ("file gif ⌫⇄ nhes", "file gif nhé"),
    ("gif⌫", "gi"),
    ("tooi  ddang vieets", "tôi  đang viết")
]
var failures = 0
for (keys, expected) in cases {
    let actual = replay(keys)
    print(actual == expected ? "PASS" : "FAIL", actual, "|", expected)
    if actual != expected { failures += 1 }
}
// Estimate manual word replacements on automatic-only replay cases.
var words = 0
var corrections = 0
for (keys, expected) in cases where !keys.contains("⇄") && !keys.contains("⌫") {
    let actual = replay(keys).split(separator: " ")
    let wanted = expected.split(separator: " ")
    words += wanted.count
    corrections += abs(actual.count - wanted.count) + zip(actual, wanted).filter { $0 != $1 }.count
}
print("Automatic replay benchmark:", corrections, "word corrections /", words, "words;",
      Double(corrections) * 1000 / Double(words), "per 1,000")
var locked = Session(model, preferences: preferences)
for c in "file" { locked.type(c) }
_ = locked.boundary(" ")
for c in "gif" { locked.type(c) }
_ = locked.boundary(" ")
let before = locked.marked
precondition(locked.toggle())
let chosen = locked.marked
for c in "nhes" { locked.type(c) }
precondition(chosen != before && locked.finish() == chosen + "nhé")
print("PASS manual choice remains locked")
// Two independent corrections teach only the same left context and survive reload.
for _ in 0..<2 {
    var session = Session(model, preferences: preferences)
    session.lookahead = false
    for c in "demo" { session.type(c) }
    _ = session.boundary(" ")
    for c in "of" { session.type(c) }
    _ = session.boundary(" ")
    let recent = session.recent!
    let caret = NSRange(location: 10, length: 0)
    precondition(recent.range(at: caret, expectedCaret: caret, read: { _ in recent.choice + " " }) != nil)
    precondition(recent.range(at: caret, expectedCaret: nil, read: { _ in recent.choice + " " }) == nil)
    precondition(recent.range(at: caret, expectedCaret: caret, read: { _ in "edited" }) == nil)
    session.correctRecent(pin: false)
    session.forget()
}
let loaded = TypingPreferences(defaults)
precondition(loaded.preference("demo|of") != nil && loaded.preference("unseen|of") == nil)
var custom = Session(model, preferences: loaded)
for c in "Tesar" { custom.type(c) }
precondition(custom.pinCurrent())
precondition(custom.finish() == "Tesar")
precondition(TypingPreferences(defaults).literal("tesar"))
// Measure the ranker with the annotated neighbouring words from the mixed corpus.
let corpus = try String(contentsOfFile: "Tests/mixed-checks.txt", encoding: .utf8)
var totals = [0, 0], errors = [0, 0]
for row in corpus.split(whereSeparator: { $0.isNewline }) {
    let fields = row.components(separatedBy: "|")
    precondition(fields.count == 3)
    let label = Int(fields[1])!
    let words = fields[2].components(separatedBy: " ")
    let index = words.firstIndex(of: "@")!
    let raw = fields[0]
    var engine = TelexEngine()
    engine.liveSpellCheck = true
    for key in raw { _ = engine.feed(key) }
    let composed = engine.composed
    let predicted = model.choose(raw: raw, composed: composed,
                                 fallback: engine.peekCommitText(autoRestore: true),
                                 left: Array(words.prefix(index)), next: words.dropFirst(index + 1).first ?? "")
    totals[label] += 1
    if predicted != (label == 1 ? raw : composed) { errors[label] += 1 }
}
print("Mixed corpus VI→EN errors", errors[0], "/", totals[0], "EN→VI errors", errors[1], "/", totals[1])
defaults.removePersistentDomain(forName: suite)
exit(failures == 0 ? 0 : 1)
