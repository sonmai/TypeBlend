import Foundation

struct Ranker {
    enum Mode: String, CaseIterable { case seed, ngram, student, cascade }
    let seed: SeedRanker
    let englishPhrases: Set<String>
    let supported: Set<String>
    let counts, learned, tags: Data
    let mode: Mode
    init(_ directory: URL, mode: Mode = .ngram) throws {
        self.mode = mode
        englishPhrases = Set(try String(contentsOf: directory.appendingPathComponent("english-phrases.txt"),
                                        encoding: .utf8).split(separator: "\n").map(String.init))
        func bytes(_ file: String) throws -> Data {
            try Data(contentsOf: directory.appendingPathComponent(file), options: .mappedIfSafe)
        }
        seed = try JSONDecoder().decode(SeedRanker.self, from: bytes("model.json"))
        let words = try String(contentsOf: directory.appendingPathComponent("collisions.txt"), encoding: .utf8)
        supported = mode == .seed ? seed.supported : Set(words.split(separator: "\n").map(String.init)).union(seed.supported)
        counts = mode == .seed || mode == .student ? Data() : try bytes("ng.bin")
        tags = counts.isEmpty ? Data() : try bytes("ng-tags.bin")
        guard tags.count == counts.count * 2 else { throw CocoaError(.fileReadCorruptFile) }
        learned = mode == .seed || mode == .ngram ? Data() : try bytes("student.bin")
        guard [counts, learned].allSatisfy({ $0.isEmpty || $0.count == 1 << 18 }) else { throw CocoaError(.fileReadCorruptFile) }
    }
    func choose(raw: String, composed: String, fallback: String, left: [String], next: String) -> String {
        let word = raw.lowercased()
        guard raw != composed, raw != raw.uppercased(), supported.contains(word) else { return fallback }
        if mode == .ngram {
            let previous = left.suffix(2).map { $0.lowercased() }
            if previous.count == 2, englishPhrases.contains((previous + [word]).joined(separator: " ")) { return raw }
            if let last = previous.last, !next.isEmpty,
               englishPhrases.contains([last, word, next.lowercased()].joined(separator: " ")) { return raw }
        }
        if mode == .seed || seed.supported.contains(word) && ["gif","max"].contains(word) {
            return seed.choose(raw: raw, composed: composed, fallback: fallback, left: left, next: next)
        }
        let b = left.last?.lowercased() ?? ""
        let a = left.dropLast().last?.lowercased() ?? ""
        let r = next.lowercased()
        func weight(_ table: Data, _ key: String, verify: Bool = false) -> Double {
            var h: UInt32 = 2166136261
            for byte in key.utf8 { h = (h ^ UInt32(byte)) &* 16777619 }
            let slot = Int(h) & (table.count - 1)
            if verify {
                let tag = UInt32(tags[slot*2]) | (UInt32(tags[slot*2+1]) << 8)
                if tag != 1 + (h >> 18) { return 0 }
            }
            return Double(Int8(bitPattern: table[slot]))/16
        }
        let local = ["L"+b,"B"+a+" "+b,"R"+r,"S"+b+" "+r].map { word+"|"+$0 }
        var score = 0.0
        if !counts.isEmpty {
            // An absent neighbour supplies no language evidence.
            if !b.isEmpty { score += weight(counts,local[0], verify: true) }
            if !a.isEmpty && !b.isEmpty { score += weight(counts,local[1], verify: true) }
            if !r.isEmpty { score += weight(counts,local[2], verify: true) }
            if !b.isEmpty && !r.isEmpty { score += weight(counts,local[3], verify: true) }
            if abs(score) >= 2 || mode == .ngram {
                return abs(score) < 1 ? fallback : (score > 0 ? raw : composed)
            }
        }
        let accented = left.suffix(4).contains { !$0.utf8.allSatisfy { $0 < 128 } }
        let extra = ["prev="+b,"right="+r,"word="+word,"accent="+(accented ? "True":"False"),
                     "suffix="+String(word.suffix(2))+"|"+b,"vi="+composed.lowercased()+"|"+r]
        score = (local+extra).reduce(0) { $0 + weight(learned,$1) }
        return abs(score) < 1 ? fallback : (score > 0 ? raw : composed)
    }
}
