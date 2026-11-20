import Cocoa
let app = NSApplication.shared
let v = NSTextView(frame: NSRect(x:0,y:0,width:600,height:200))
let model = try Ranker(URL(fileURLWithPath: CommandLine.arguments[1]))
let none = NSRange(location:NSNotFound,length:0)
var s = Session(model)
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

var inline = InlineComposition()
v.string = "📌 [chèn] sau"
v.setSelectedRange((v.string as NSString).range(of: "[chèn]"))
s = Session(model)
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
