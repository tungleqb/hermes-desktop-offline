import json, re, pathlib
root = pathlib.Path(r'D:\dev\hermes-agent')
out = []
for base in ('skills', 'optional-skills', 'plugins'):
    p = root / base
    if not p.exists():
        continue
    for md in sorted(p.rglob('SKILL.md')):
        text = md.read_text(encoding='utf-8', errors='replace')
        http = re.findall(r'https?://[^\s)\]"\`]+', text)
        remote = [u for u in http if not any(h in u for h in ('localhost', '127.0.0.1', 'example.com'))]
        apiish = bool(re.search(r'(?i)(api[_ ]key|token|oauth|curl -|requests\.get|fetch\(|http\.get|wget |endpoint)', text))
        out.append({'name': md.parent.name, 'path': str(md.parent.relative_to(root)),
                    'remote_urls': len(remote), 'needs_api': apiish, 'sample': remote[:3], 'chars': len(text)})
dst = pathlib.Path(r'D:\dev\hermes-desktop-offline\artifacts')
dst.mkdir(parents=True, exist_ok=True)
json.dump(out, open(dst / 'skill_inventory.json', 'w', encoding='utf-8'), indent=1)
print('total skills:', len(out))
print('offline-capable:', sum(1 for o in out if o['remote_urls'] == 0 and not o['needs_api']))
print('network-dependent:', sum(1 for o in out if o['remote_urls'] > 0 or o['needs_api']))
