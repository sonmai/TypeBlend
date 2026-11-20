import re
from pathlib import Path
txt=Path('../data/en_ewt-train.conllu').read_text()
words=set(re.findall(r'\b[a-z]+\b',' '.join(l.partition('=')[2].lower() for l in txt.splitlines() if l.startswith('# text'))))
words.update(re.findall(r'\b([a-z]+)=[0-9a-f]{4}\b',Path('TelexCore/EnglishFrequency.swift').read_text()))
words.update(l.split('|')[0] for l in Path('Tools/phrases.txt').read_text().splitlines() if '|' in l)
print('\n'.join(sorted(words)))
