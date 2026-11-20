import Foundation

final class TypingPreferences {
    static let shared = TypingPreferences(.standard)
    private let defaults: UserDefaults
    private var names: Set<String>
    private var prefixes: Set<String> = []
    private var choices: [String: Int]

    init(_ defaults: UserDefaults) {
        self.defaults = defaults
        names = Set((defaults.stringArray(forKey: "LiteralNames") ?? []).map { $0.lowercased() })
        choices = defaults.dictionary(forKey: "ContextCorrections") as? [String: Int] ?? [:]
        rebuildPrefixes()
    }

    private func rebuildPrefixes() {
        prefixes = Set(names.union(["zara"]).flatMap { name in name.indices.map { String(name[...$0]) } })
    }
    func literal(_ text: String) -> Bool { text.lowercased() == "zara" || names.contains(text.lowercased()) }
    func prefix(_ text: String) -> Bool { prefixes.contains(text.lowercased()) }
    func pin(_ text: String) {
        if names.insert(text.lowercased()).inserted {
            defaults.set(names.sorted(), forKey: "LiteralNames")
            rebuildPrefixes()
        }
    }
    func preference(_ key: String?) -> Bool? {
        guard let key, let votes = choices[key], abs(votes) >= 2 else { return nil }
        return votes > 0
    }
    func record(_ key: String?, raw: Bool) {
        guard let key else { return }
        if choices.count >= 1024, choices[key] == nil, let first = choices.keys.first {
            choices.removeValue(forKey: first)
        }
        choices[key] = max(-3, min(3, (choices[key] ?? 0) + (raw ? 1 : -1)))
        defaults.set(choices, forKey: "ContextCorrections")
    }
}
