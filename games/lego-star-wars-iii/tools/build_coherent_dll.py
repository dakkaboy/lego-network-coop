from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess

here=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--with-hit-entry-observer',action='store_true')
parser.add_argument('--source',type=Path,default=here/'src')
parser.add_argument('--output',type=Path,default=here/'build/net-live28')
parser.set_defaults(bootstrap=True,remote_trace_off=True)
args=parser.parse_args()
src=args.source.resolve()
out=args.output.resolve()
out.mkdir(parents=True,exist_ok=True)
layout=re.search(r'#define\s+SYNC_LAYOUT_VERSION\s+(\d+)',(src/'net/sync_wire.h').read_text())
if not layout or int(layout[1]) not in (28,29) or not (src/'sync/coherent_core_body.inc').is_file() or not (src/'engine/user_mapping_install.c').is_file():
    raise SystemExit('Integrated coherent Core sources are required')
zig=shutil.which('zig')
clang=shutil.which('clang')
assert zig and clang
results=[]
def run(args):
    p=subprocess.run(list(map(str,args)),capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW,timeout=180)
    results.append({'command':list(map(str,args)),'code':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
    (out/'commands.json').write_text(json.dumps(results,indent=2))
    if p.returncode:
        print(p.stderr)
        p.check_returncode()

def source_hashes():
    return {p.relative_to(src).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(src.rglob('*')) if p.is_file()}

before=source_hashes()
seh=sorted(src.rglob('*seh.c'))
for source in seh:
    run([clang,'-target','i686-pc-windows-msvc','-O2','-I'+str(src),'-c',source,'-o',out/(source.stem+'.obj')])
excluded=set([source.stem for source in seh]+['proxy','pose_observer','intent_frame_observer','intent_scope_observer','steering_sync','steering_journal','equipment_oracle','action_transition_observer','base_aim_observer','constructor_observer','constructor_query_observer'])
if not args.with_hit_entry_observer:excluded.add('hit_entry_observer')
sources=[p for p in src.rglob('*.c') if p.stem not in excluded]
sources+=list(src.rglob('*.S'))
cpp_objects=[]
for source in sorted(src.rglob('*.cpp')):
    obj=out/(source.stem+'.cpp.obj')
    run([zig,'c++','-target','x86-windows-gnu','-std=c++23','-O2','-fno-exceptions','-fno-rtti','-I'+str(src),'-c',source,'-o',obj])
    cpp_objects.append(obj)
dll=out/'clonewars-camera.dll'
defines=[]
if args.with_hit_entry_observer:defines.append('-DCLONEWARS_HIT_ENTRY_OBSERVER')
if args.bootstrap:defines.append('-DCOHERENT_CORE_REVIEWED_BOOTSTRAP')
if args.remote_trace_off:defines.append('-DCLONEWARS_REMOTE_INPUT_TRACE_DISABLED')
run([zig,'cc','-target','x86-windows-gnu','-shared','-O2','-fms-extensions','-I'+str(src),*defines,*sources,*cpp_objects,*[out/(source.stem+'.obj') for source in seh],'-o',dll,'-luser32','-lws2_32'])
proxy=out/'d3d9.dll'
run([zig,'cc','-target','x86-windows-gnu','-shared','-O2',src/'engine/proxy.c',src/'engine/proxy.def','-o',proxy])
assert before==source_hashes(),'Sources changed during build'
(out/'build-info.json').write_text(json.dumps({'dll_sha256':hashlib.sha256(dll.read_bytes()).hexdigest(),'proxy_sha256':hashlib.sha256(proxy.read_bytes()).hexdigest(),'layout_version':int(layout[1]),'wire_version':int(layout[1]),'mode':'normal','model_input_authority':True,'optional_observers':args.with_hit_entry_observer,'hit_entry_observer':args.with_hit_entry_observer,'linked':True,'runtime_verified':False,'installed':False,'bootstrap_requested':args.bootstrap,'remote_trace_disabled':args.remote_trace_off,'sources':before},indent=2))
print('Linked',dll,'not runtime-verified or installed')
