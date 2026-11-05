import sys, glob, re, collections
base = sys.argv[1]
pat = collections.Counter()
for d in glob.glob(base + '/logs_*'):
    try:
        f = open(d + '/PlayerHomelandAILog.csv', encoding='latin-1')
    except OSError:
        continue
    for line in f:
        if 'gold' not in line.lower():
            continue
        p = line.split(',', 2)
        txt = p[2] if len(p) > 2 else line
        txt = re.sub(r'\d+', 'N', txt.strip())[:90]
        pat[txt] += 1
for k, v in pat.most_common(20):
    print(v, '|', k)
