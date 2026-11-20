"""Extract three-word English runs from the annotated mixed typing corpus."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
phrases = set()
for source in ["mixed-typing-handwritten.txt", "workplace-mixed.tsv"]:
    for line in (root / "Tools" / source).read_text().splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        run = []
        for token in line.split("\t", 1)[1].lower().split():
            match = re.fullmatch(r"([a-z]+)/e([.,!?]?)", token)
            if not match:
                run.clear()
                continue
            run.append(match[1])
            if len(run) >= 3:
                phrases.add(" ".join(run[-3:]))
            if match[2]:
                run.clear()
(root / "Resources/english-phrases.txt").write_text("\n".join(sorted(phrases)) + "\n")
