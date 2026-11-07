from pathlib import Path
import gzip, hashlib, json, re

root = Path(__file__).resolve().parents[1]
site = root.parent / 'ucb-mobile-hotfix-site'
dist = site / 'dist'
page = (dist / 'index.html').read_text(encoding='utf-8')
manifest = json.loads(re.search(r'const ucbChunks=(.*?);\n', page).group(1))
data = (root / 'build/web/index.pck').read_bytes()
prefix = 'mobile-' + hashlib.sha256(data).hexdigest()[:10] + '-index.pck'
entry = {'size': len(data)}
for mode, content in [('gzip', gzip.compress(data, compresslevel=9, mtime=0)), ('raw', data)]:
    names = []
    for i, start in enumerate(range(0, len(content), 4*1024*1024)):
        name = f'{prefix}.{mode}.{i:02}'
        (dist/name).write_bytes(content[start:start+4*1024*1024])
        names.append(name)
    entry[mode] = {'chunks': names, 'size': len(content)}
manifest['index.pck'] = entry
page = re.sub(r'const ucbChunks=.*?;\n', 'const ucbChunks='+json.dumps(manifest)+';\n', page)
page = re.sub(r'"fileSizes":\{"index.pck":\d+', '"fileSizes":{"index.pck":'+str(len(data)), page)
for file in [dist/'index.html', site/'index.html']:
    file.write_text(page, encoding='utf-8')
print(json.dumps({'pck': len(data), 'total_download': sum(v['gzip']['size'] for v in manifest.values())}))
