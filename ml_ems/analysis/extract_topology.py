"""Read-only OPC model inventory. Writes only under ml_ems/analysis/evidence."""
from pathlib import Path
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'EMT.mdl'
raw = source.read_bytes()
text = raw.decode('utf-8')
markers = list(re.finditer(r'^__MWOPC_PART_BEGIN__ (.+)$', text, re.M))
parts = {}
for i, match in enumerate(markers):
    name = match.group(1).strip()
    body = text[match.end():markers[i + 1].start() if i + 1 < len(markers) else len(text)].strip()
    body = re.split(r'\n__MWOPC_PACKAGE_END__', body)[0].strip()
    if name.endswith('.xml'):
        parts[name] = (ET.fromstring(body), text[:match.end()].count('\n') + 1)

def props(node):
    return {p.get('Name'): p.text or '' for p in node.findall('P')}

blocks = []
systems = {}
for name, (tree, line) in parts.items():
    if name.startswith('/simulink/systems/'):
        systems[Path(name).stem] = tree
        for block in tree.findall('Block'):
            ref = block.find('System')
            blocks.append(dict(sid=block.get('SID'), name=block.get('Name'),
                               type=block.get('BlockType'), part=name,
                               part_line=line, parameters=props(block),
                               system_ref=ref.get('Ref') if ref is not None else None))

def describe_lines(tree):
    result = []
    for line in tree.findall('Line'):
        info = props(line)
        info['destinations'] = [p.text for p in line.iter('P') if p.get('Name') == 'Dst']
        result.append(info)
    return result

tags = {}
for block in blocks:
    tag = block['parameters'].get('GotoTag')
    if tag:
        tags.setdefault(tag, []).append({k: block[k] for k in ('sid', 'name', 'type', 'part')})

deps = Counter(b['parameters']['SourceBlock'].split('/')[0] for b in blocks
               if b['type'] == 'Reference' and 'SourceBlock' in b['parameters'])
output = dict(source=str(source), sha256=hashlib.sha256(raw).hexdigest(),
              parsed_xml_parts=len(parts), system_count=len(systems), block_count=len(blocks),
              library_reference_counts=dict(deps), blocks=blocks, tag_connections=tags,
              key_system_lines={key: describe_lines(systems[key]) for key in
                                ('system_11342', 'system_11358', 'system_11143') if key in systems},
              verification_scope='static XML inventory; runtime compilation is in runtime_audit.json')
destination = ROOT / 'ml_ems/analysis/evidence/topology_static.json'
destination.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: output[k] for k in ('parsed_xml_parts', 'system_count', 'block_count',
                                      'library_reference_counts')}, ensure_ascii=False))
