from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess

here = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--with-hit-entry-observer', action='store_true')
parser.add_argument('--with-constructor-query-observer', action='store_true')
parser.add_argument('--tracy', action='store_true')
parser.add_argument('--source', type=Path, default=here / 'src')
parser.add_argument('--output', type=Path, default=here / 'build/net-live')
parser.add_argument('--zig', default='zig')
args = parser.parse_args()
src = args.source.resolve()
out = args.output.resolve()
project = src.parent
zig = shutil.which(args.zig)
if not zig:
    raise SystemExit('Zig 0.17.1 is required; pass --zig.')
version = subprocess.check_output([zig, 'version'], text=True).strip()
if version != '0.17.1':
    raise SystemExit(f'Zig 0.17.1 is required; found {version}.')
protocol = (src / 'zig/protocol.zig').read_text()
versions = {}
for name in ('LAYOUT', 'WIRE'):
    match = re.search(r'SYNC_' + name + r'_VERSION = @as\(c_int, (\d+)\)', protocol)
    if not match:
        raise SystemExit(f'Missing {name.lower()} version in Zig protocol.')
    versions[name.lower()] = int(match[1])
out.mkdir(parents=True, exist_ok=True)
results = []


def run(command):
    command = list(map(str, command))
    result = subprocess.run(command, cwd=project, capture_output=True, text=True,
                            creationflags=subprocess.CREATE_NO_WINDOW, timeout=300)
    results.append({'command': command, 'code': result.returncode,
                    'stdout': result.stdout, 'stderr': result.stderr})
    (out / 'commands.json').write_text(json.dumps(results, indent=2))
    if result.returncode:
        print(result.stdout)
        print(result.stderr)
        result.check_returncode()


def source_hashes():
    files = sorted(path for path in (src / 'zig').rglob('*') if path.is_file())
    files += [src / 'engine/proxy.def', project / 'build.zig', project / 'build.zig.zon']
    return {path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in files}


before = source_hashes()
run([zig, 'build', 'dll', '--prefix', out, '--prefix-exe-dir', '.',
     '-Dhit-entry=' + str(args.with_hit_entry_observer).lower(),
     '-Dconstructor-query=' + str(args.with_constructor_query_observer).lower(),
     '-Dtracy=' + str(args.tracy).lower()])
if before != source_hashes():
    raise SystemExit('Sources changed during build.')
dll = out / 'clonewars-camera.dll'
proxy = out / 'd3d9.dll'
(out / 'build-info.json').write_text(json.dumps({
    'dll_sha256': hashlib.sha256(dll.read_bytes()).hexdigest(),
    'proxy_sha256': hashlib.sha256(proxy.read_bytes()).hexdigest(),
    'layout_version': versions['layout'], 'wire_version': versions['wire'],
    'zig_version': version, 'mode': 'normal', 'model_input_authority': True,
    'optional_observers': args.with_hit_entry_observer or args.with_constructor_query_observer,
    'hit_entry_observer': args.with_hit_entry_observer,
    'constructor_query_observer': args.with_constructor_query_observer,
    'tracy': args.tracy,
    'linked': True, 'runtime_verified': False, 'installed': False,
    'bootstrap_requested': True, 'remote_trace_disabled': True, 'sources': before,
}, indent=2))
print('Linked', dll, 'not runtime-verified or installed')
