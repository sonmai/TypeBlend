import Cocoa
import InputMethodKit
import Carbon

let noRange = NSRange(location: NSNotFound, length: 0)
let model = try Ranker(Bundle.main.resourceURL!)

@objc(SongNguController)
class SongNguController: IMKInputController {
    private var session = Session(model)
    private func display(_ client: IMKTextInput, committed: String = "") {
        if !committed.isEmpty { client.insertText(committed, replacementRange: noRange) }
        let text = session.marked
        if !text.isEmpty || (committed.isEmpty && client.markedRange().location != NSNotFound) {
            client.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0), replacementRange: noRange)
        }
    }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        let flags = event.modifierFlags.intersection([.command, .option, .control])
        if flags == .control, event.charactersIgnoringModifiers == ";", session.toggle() { display(client); return true }
        if !flags.isEmpty { commitComposition(sender); return false }
        if event.keyCode == 51 {
            guard session.backspace() else { return false }
            display(client)
            return true
        }
        guard let chars = event.characters, chars.count == 1, let c = chars.first,
              c.isASCII, c.isLetter || c == " " || c.isNumber || c.isPunctuation else {
            commitComposition(sender)
            return false
        }
        session.lookahead = !["com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode"].contains(client.bundleIdentifier() ?? "")
        if c.isLetter { session.type(c); display(client) }
        else { let output = session.boundary(String(c)); display(client, committed: output) }
        return true
    }
    override func commitComposition(_ sender: Any!) {
        if session.active, let client = sender as? IMKTextInput {
            let output = session.finish()
            display(client, committed: output)
        }
        session.forget()
    }
    override func deactivateServer(_ sender: Any!) { commitComposition(sender); super.deactivateServer(sender) }
}

if CommandLine.arguments.contains("--register") {
    exit(TISRegisterInputSource(Bundle.main.bundleURL as CFURL) == noErr ? 0 : 1)
}
let app = NSApplication.shared
let server = IMKServer(name: "org.songngu.inputmethod.Telex_Connection", bundleIdentifier: Bundle.main.bundleIdentifier)
app.run()
