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
        v.setMarkedText(text,selectedRange:NSRange(location:text.utf16.count,length:0),replacementRange:none)
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
