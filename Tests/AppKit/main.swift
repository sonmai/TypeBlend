import Cocoa
let app = NSApplication.shared
let v = NSTextView(frame: NSRect(x:0,y:0,width:600,height:200))
let model = try Ranker(URL(fileURLWithPath: CommandLine.arguments[1]))
let none = NSRange(location:NSNotFound,length:0)
let suite = "TypeBlendAppKit-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
let prefs = TypingPreferences(defaults)
var s = Session(model, preferences: prefs)
func update(_ commit: String) {
    if !commit.isEmpty { v.insertText(commit,replacementRange:none) }
    let text = s.marked
    if !text.isEmpty || (commit.isEmpty && v.hasMarkedText()) {
        let marked = markedTextForDisplay(text)
        if marked.length > 0 {
            marked.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: marked.length)) { style, _, _ in
                precondition((style as? NSNumber)?.intValue == 0)
            }
        }
        v.setMarkedText(marked, selectedRange:NSRange(location:text.utf16.count,length:0),replacementRange:none)
    }
}
v.string = "📌 [chèn] sau"
v.setSelectedRange((v.string as NSString).range(of:"[chèn]"))
for c in "Guwir minhf file gif nhes. Banj vuwaf guwir minhf file gif vaayj?" {
    if c.isLetter { s.type(c); update("") }
    else { let commit = s.boundary(String(c)); update(commit) }
}
let commit = s.finish()
update(commit)
print(v.string)
guard v.string == "📌 Gửi mình file gif nhé. Bạn vừa gửi mình file gì vậy? sau", !v.hasMarkedText() else { exit(1) }

for id in ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.apple.Safari",
           "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac",
           "com.brave.Browser", "company.thebrowser.Browser"] {
    precondition(InlineComposition.enabled(in: id), id)
}
for id in [nil, "com.apple.Terminal", "com.google.Chrome.app.example"] {
    precondition(!InlineComposition.enabled(in: id))
}

var inline = InlineComposition()
v.string = "📌 [chèn] sau"
v.setSelectedRange((v.string as NSString).range(of: "[chèn]"))
s = Session(model, preferences: prefs)
func inlineUpdate(_ committed: String) {
    inline.display(committed: committed, composing: s.marked, selection: v.selectedRange()) {
        v.insertText($0, replacementRange: $1)
    }
    precondition(!v.hasMarkedText())
    precondition(inline.matches(v.selectedRange()) { (v.string as NSString).substring(with: $0) })
}
for c in "Guwir minhf file gif nhes. Banj vuwaf guwir minhf file gif vaayj?" {
    if c.isLetter { s.type(c); inlineUpdate("") }
    else { let commit = s.boundary(String(c)); inlineUpdate(commit) }
}
inlineUpdate(s.finish())
precondition(v.string == "📌 Gửi mình file gif nhé. Bạn vừa gửi mình file gì vậy? sau")
for c in "of" { s.type(c); inlineUpdate("") }
precondition(s.toggle())
inlineUpdate("")
precondition(s.backspace())
inlineUpdate("")
v.setSelectedRange(NSRange(location: 0, length: 0))
precondition(!inline.matches(v.selectedRange()) { _ in nil })

// Replace only our last committed word and separator, after a UTF-16 surrogate pair.
s = Session(model, preferences: prefs)
s.lookahead = false
v.string = "📌 "
v.setSelectedRange(NSRange(location: v.string.utf16.count, length: 0))
for c in "gif" { s.type(c) }
v.insertText(s.boundary(" "), replacementRange: none)
let caret = v.selectedRange()
let recent = s.recent!
let target = recent.range(at: caret, expectedCaret: caret) { (v.string as NSString).substring(with: $0) }!
s.correctRecent(pin: false)
v.insertText(s.recent!.choice + " ", replacementRange: target)
precondition(v.string == "📌 " + (recent.choice == "gif" ? "gì " : "gif "))
precondition(!v.hasMarkedText() && v.selectedRange().location == v.string.utf16.count)
defaults.removePersistentDomain(forName: suite)
