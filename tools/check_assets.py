from pathlib import Path
from PIL import Image
import json,sys,hashlib
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'docs/asset_manifest.json').read_text(encoding='utf-8'))
for obj in manifest['assets']:
    p=root/obj['path']; assert p.is_file(),p
    with Image.open(p) as image:
        image.load(); assert image.size==(obj['w'],obj['h']), p
        if obj['group']!='backgrounds':
            assert image.mode=='RGBA' and image.getchannel('A').getextrema()[0]==0, p
    assert hashlib.sha256(p.read_bytes()).hexdigest()==obj['sha256'], p
print('PASS',len(manifest['assets']),'assets')
