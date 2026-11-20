import Foundation

struct SeedRanker: Decodable {
    struct Weights: Decodable {
        let key, value, pos, hidden, head: [[Double]]
        let bias, outputBias: [Double]
        enum CodingKeys: String, CodingKey {
            case key = "key.weight", value = "value.weight", pos
            case hidden = "hidden.weight", head = "head.weight"
            case bias = "hidden.bias", outputBias = "head.bias"
        }
    }
    let vocab: [String:Int]
    let supported: Set<String>
    let weights: Weights

    func choose(raw: String, composed: String, fallback: String, left: [String], next: String) -> String {
        let word = raw.lowercased()
        guard supported.contains(word), raw != composed,
              let queryID = vocab["@" + word], raw != raw.uppercased() else { return fallback }
        let previous = Array(left.suffix(12))
        var slots = [Int](repeating: 0, count: 12 - previous.count)
        slots += previous.map { vocab[$0.lowercased(), default: 0] }
        slots += [queryID, vocab[next.lowercased(), default: 0]]
        guard slots.enumerated().contains(where: { $0.offset != 12 && $0.element != 0 }) else { return fallback }
        let w = weights
        let query = w.key[queryID]
        var vector = [Double](repeating: 0, count: query.count)
        var denominator = 0.0
        for (position, id) in slots.enumerated() where id != 0 {
            var score = 0.0
            for k in query.indices { score += (w.key[id][k] + w.pos[position][k]) * query[k] }
            let attention = exp(score / 4)
            denominator += attention
            for k in vector.indices { vector[k] += attention * w.value[id][k] }
        }
        for k in vector.indices { vector[k] = vector[k] / denominator + w.value[queryID][k] }
        var logit = w.outputBias[0]
        for j in w.hidden.indices {
            var activation = w.bias[j]
            for k in vector.indices { activation += w.hidden[j][k] * vector[k] }
            logit += max(0, activation) * w.head[0][j]
        }
        if abs(logit) < 1.1 { return fallback }
        return logit > 0 ? raw : composed
    }
}
