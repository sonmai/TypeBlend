"""Train a small candidate-conditioned attention ranker. Run from project root."""
import json
import re
from pathlib import Path
import torch
from torch import nn

torch.manual_seed(19)
torch.set_num_threads(1)
pairs = dict(gif="gì", max="mã", car="cả", bar="bả", bus="bú", his="hí",
             now="nơ", last="lát", its="ít", of="ò", is_="í", own="ơn", as_="á")
pairs["is"] = pairs.pop("is_")
pairs["as"] = pairs.pop("as_")
examples = []

def record(words, i, raw, label):
    left = words[max(0, i-12):i]
    right = words[i+1:i+2]
    for tail in ([right, []] if right else [[]]):
        examples.append((raw, left, tail, float(label)))

for line in Path("Tools/mixed-typing-handwritten.txt").read_text().splitlines():
    if line.startswith("#") or "\t" not in line:
        continue
    tokens = re.findall(r"([^\W\d_]+)(/e)?", line.split("\t", 1)[1].lower())
    words = [w for w, _ in tokens]
    for i, (word, english) in enumerate(tokens):
        for raw, vi in pairs.items():
            if (english and word == raw) or (not english and word == vi):
                record(words, i, raw, bool(english))

# Independent short training phrases, with combinations of speaker and recipient.
for line in Path("Tools/phrases.txt").read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    raw, label, phrase = line.split("|")
    for prefix in ["", "hôm nay ", "chị hỏi ", "em bảo "]:
        words = (prefix + phrase).split()
        record(words, words.index("@"), raw, int(label))

vocab = {"<pad>": 0}
def index(token):
    return vocab.setdefault(token, len(vocab))

inputs, labels = [], []
for raw, left, right, label in examples:
    # Slots 0..11 are left context, 12 is the candidate, 13 the next word.
    inputs.append([0]*(12-len(left)) + [index(w) for w in left] +
                  [index("@"+raw), index(right[0]) if right else 0])
    labels.append(label)
x, y = torch.tensor(inputs), torch.tensor(labels)
class Ranker(nn.Module):
    def __init__(self):
        super().__init__()
        self.key = nn.Embedding(len(vocab), 16, padding_idx=0)
        self.value = nn.Embedding(len(vocab), 16, padding_idx=0)
        self.pos = nn.Parameter(torch.zeros(14, 16))
        self.hidden = nn.Linear(16, 20)
        self.head = nn.Linear(20, 1)

    def forward(self, ids):
        keys = self.key(ids) + self.pos
        query = self.key(ids[:, 12])
        logits = (keys * query[:, None]).sum(-1) / 4
        att = logits.masked_fill(ids == 0, -1e4).softmax(1)
        pooled = (self.value(ids) * att[..., None]).sum(1) + self.value(ids[:, 12])
        return self.head(self.hidden(pooled).relu()).squeeze(1)

model = Ranker()
optimizer = torch.optim.AdamW(model.parameters(), lr=.025)
for epoch in range(170):
    for ix in torch.randperm(len(x)).split(128):
        loss = nn.functional.binary_cross_entropy_with_logits(model(x[ix]), y[ix])
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
weights = {name: value.detach().tolist() for name, value in model.named_parameters()}
supported = sorted({w for w in pairs if {e[3] for e in examples if e[0] == w} == {0, 1}})
Path("Resources/model.json").write_text(json.dumps(dict(vocab=vocab, supported=supported, weights=weights)))
print(len(examples), "training windows;", supported)
