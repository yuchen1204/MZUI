#!/usr/bin/env python3
"""Build an installable mod ZIP without tests, backups or game files."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parent.parent
MOD = ROOT / 'mods' / 'MZUI'
info = dict(line.split('=', 1) for line in (MOD / '42/mod.info').read_text().splitlines() if '=' in line)
version = info['modversion']
out = ROOT / 'dist'
out.mkdir(exist_ok=True)
archive = out / f'MZUI-{version}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted((MOD / '42').rglob('*')):
        if path.is_file() and path.suffix in {'.lua', '.json', '.png', '.info'}:
            bundle.write(path, (Path('MZUI') / path.relative_to(MOD)).as_posix())
    bundle.writestr('MZUI/common/', '')
    bundle.write(MOD / 'README.md', 'MZUI/README.md')
    bundle.write(ROOT / 'LICENSE', 'MZUI/LICENSE')
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / f'{archive.name}.sha256').write_text(f'{digest}  {archive.name}\n')
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert 'MZUI/42/mod.info' in bundle.namelist()
print(archive)
print(digest)
