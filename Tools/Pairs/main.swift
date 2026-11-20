import Foundation
while let raw = readLine() {
    var engine = TelexEngine()
    engine.liveSpellCheck = true
    for c in raw { _ = engine.feed(c) }
    let alt = engine.composed
    if raw != alt && alt.unicodeScalars.contains(where: { !$0.isASCII }) {
        print([raw, alt, engine.commitText(autoRestore: true)].joined(separator: "\t"))
    }
}
