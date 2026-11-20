"""From project root: python Tools/fit_context.py. Inputs in ../data and ../xlmr."""
import collections, hashlib, json, math, random, re, struct
from pathlib import Path
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

random.seed(417)
torch.manual_seed(417)
torch.set_num_threads(3)
N = 1 << 18
def full_hash(s):
    h = 2166136261
    for b in s.encode():
        h = ((h ^ b)*16777619) & 0xffffffff
    return h

def bucket(s):
    return full_hash(s) % N

def sentences(split):
    for p in sorted(Path('../data').glob('*-'+split+'.conllu')):
        for line in p.read_text().splitlines():
            if line.startswith('# text'):
                yield re.findall(r'[^\W\d_]+',line.partition('=')[2].lower())

train = list(sentences('train'))
seen = {tuple(s) for s in train}
def read_mixed():
    for line in Path('Tools/mixed-typing-handwritten.txt').read_text().splitlines():
        if not line.startswith('#') and '\t' in line:
            yield re.findall(r'[^\W\d_]+',line.split('\t')[1].replace('/e','').lower())
train.extend(read_mixed())
counts = collections.Counter(w for s in train for w in s)
pairs = {}
reverse = collections.defaultdict(list)
for row in Path('Resources/pairs.tsv').read_text().splitlines():
    raw,vi,base=row.split('\t')
    if counts[vi] and counts[raw] or raw in {'gif','max'}:
        pairs[raw]=(vi,base)
        reverse[vi].append(raw)
for line in Path('Tools/phrases.txt').read_text().splitlines():
    if '|' in line:
        raw, label, phrase=line.split('|')
        if raw in pairs:
            train.append(phrase.replace('@',raw if int(label) else pairs[raw][0]).split())
seen.update(tuple(s) for s in train)

def rows(sentences):
    for s in sentences:
        for i,w in enumerate(s):
            keys=([w] if w in pairs else []) + reverse.get(w,[])
            for raw in keys:
                yield raw, pairs[raw][0],s[max(i-8,0):i],s[i+1:i+2],int(w==raw)

def features(raw,alt,left,right):
    a,b=(['','']+left)[-2:]
    r=(right+[''])[0]
    # Lexical n-grams, shared context features, and local language cues.
    return [raw+'|'+v for v in ['L'+b,'B'+a+' '+b,'R'+r,'S'+b+' '+r]] + [
        'prev='+b,'right='+r,'word='+raw,'accent='+str(any(not w.isascii() for w in left[-4:])),
        'suffix='+raw[-2:]+'|'+b,'vi='+alt+'|'+r]
data=list(rows(train))
random.shuffle(data)
print('sentences',len(train),'pairs',len(pairs),'ambiguous decisions',len(data),flush=True)
# Estimate local log odds for each candidate and surrounding 2/3-grams.
hits=collections.defaultdict(lambda:[0,0])
for raw,alt,left,right,y in data:
    for f in features(raw,alt,left,right)[:4]:
        hits[f][y]+=1
ng=np.zeros(N)
tags=np.zeros(N,dtype="<u2")
for f,(a,b) in sorted(hits.items(),key=lambda x:sum(x[1])):
    tags[bucket(f)] = 1 + (full_hash(f) >> 18)
    ng[bucket(f)] = math.log((b+.75)/(a+.75))
Path("Resources/ng-tags.bin").write_bytes(tags.tobytes())
# Teacher: frozen multilingual encoder, supervised binary head on [CLS].
tok=AutoTokenizer.from_pretrained('../xlmr')
teacher=AutoModel.from_pretrained('../xlmr').eval()
batch=data[:1800]
texts=[' '.join(l+[tok.mask_token]+r)+' </s> '+raw+' / '+alt for raw,alt,l,r,y in batch]
enc=[]
with torch.inference_mode():
    for i in range(0,len(texts),24):
        keys=tok(texts[i:i+24],padding=True,truncation=True,max_length=48,return_tensors='pt')
        hidden=teacher(**keys).last_hidden_state
        idx=(keys.input_ids==tok.mask_token_id).int().argmax(1)
        enc.append(hidden[torch.arange(len(idx)), idx].clone())
del teacher
x=torch.cat(enc)
y=torch.tensor([float(row[-1]) for row in batch])
head=torch.nn.Linear(x.shape[-1],1)
optimizer=torch.optim.AdamW(head.parameters(),lr=.01)
for epoch in range(70):
    pred=head(x).flatten()
    loss=torch.nn.functional.binary_cross_entropy_with_logits(pred,y)
    optimizer.zero_grad(); loss.backward(); optimizer.step()
soft=torch.sigmoid(head(x).flatten()).detach().tolist()
# Sparse student uses teacher soft targets for the encoder subset, human text for remainder.
X=[];Y=[]
for i,(raw,alt,l,r,label) in enumerate(data):
    for tail in ([r,[]] if r else [r]):
        X.append([bucket(f) for f in features(raw,alt,l,tail)])
        Y.append(.5*label+.5*soft[i] if i<len(soft) and tail==r else label)
X=np.array(X); Y=np.array(Y)
student=np.zeros(N)
rng=np.random.default_rng(417)
for epoch in range(16):
    for ix in np.array_split(rng.permutation(len(Y)),max(1,len(Y)//100)):
        p=1/(1+np.exp(-np.clip(student[X[ix]].sum(1),-20,20)))
        np.add.at(student,X[ix],(.015*(Y[ix]-p))[:,None])
for name,table in [('ng',ng),('student',student)]:
    Path('Resources/'+name+'.bin').write_bytes(np.round(np.clip(table,-7.9,7.9)*16).astype('int8').tobytes())
Path('Resources/collisions.txt').write_text('\n'.join(sorted(pairs))+'\n')
for split in ('dev','test'):
    holdout=[s for s in sentences(split) if tuple(s) not in seen]
    out=[]
    for raw,alt,l,r,y in rows(holdout):
        out.append('\t'.join([raw,alt,pairs[raw][1],' '.join(l),' '.join(r),str(y)]))
    Path('../data/'+split+'.tsv').write_text('\n'.join(out)+'\n')
    if split=='dev': seen.update(tuple(s) for s in holdout)
    print(split,len(out))
