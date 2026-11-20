import AppKit

func markedTextForDisplay(_ text: String) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [.underlineStyle: 0])
}
