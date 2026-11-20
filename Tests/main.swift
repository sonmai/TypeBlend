import Foundation

let model = try Ranker(URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent())
func replay(_ keys: String) -> String {
    var session = Session(model)
    var output = ""
    for c in keys {
        if c == "⌫" { _ = session.backspace() }
        else if c == "⇄" { precondition(session.toggle()) }
        else if c.isLetter { session.type(c) }
        else { output += session.boundary(String(c)) }
    }
    return output + session.finish()
}
var brand = Session(model)
var prefix = ""
for c in "Zara" {
    prefix.append(c)
    brand.type(c)
    precondition(brand.marked == prefix)
}
let cases = [
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
var locked = Session(model)
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
exit(failures == 0 ? 0 : 1)
