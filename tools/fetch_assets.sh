#!/usr/bin/env bash
set -euo pipefail

mkdir -p assets/characters
# Grab3D CC0-1.0 rigged 2K PBR GLB assets. Original model pages:
# https://grab3d.com/models/characters/man/
# https://grab3d.com/models/characters/man-base-character/
# Every downloaded source is checked for GLB binary format below.
fetch_glb() {
  local url="$1" out="$2"
  if [ ! -s "$out" ]; then
    echo "Downloading licensed 3D asset: $url"
    curl --retry 3 --retry-all-errors -fL --max-time 120 "$url" -o "$out"
  fi
  python3 - "$out" <<'PY'
import sys,struct,json,os
p=sys.argv[1]
with open(p,'rb') as f:
    h=f.read(20)
    assert len(h)==20 and h[:4]==b'glTF', f"Not a real GLB: {p}"
    version,length=struct.unpack_from('<II',h,4)
    assert version==2 and 50000<=length<=90000000 and length==os.path.getsize(p), (version,length,os.path.getsize(p))
    chunklen,typ=struct.unpack_from('<I4s',h,12)
    assert typ==b'JSON'
    data=json.loads(f.read(chunklen).decode('utf8'))
    print(f"GLB_VALID {p} {length} bytes skins={len(data.get('skins',[]))} animations={len(data.get('animations',[]))}")
    print('BONES:',','.join(data['nodes'][i].get('name','?') for i in data.get('skins',[{}])[0].get('joints',[])) if data.get('skins') else '(static)')
    print('MATERIALS:', [(m.get('name','material'),m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[])) for m in data.get('materials',[])][:30])
    print('MESHES:', [m.get('name','mesh') for m in data.get('meshes',[])][:30])
PY
}
# Upgrade initial test assets: a real elderly clothed rig for Bomj and the
# bearded jacket model for Gopnik (instead of a barefoot T-shirt mannequin).
if [ -f assets/characters/bomj.glb ] && [ "$(git hash-object assets/characters/bomj.glb)" = "9340d101b78cf48994dbd6c85da37a92a630aea2" ]; then
  mv -f assets/characters/bomj.glb assets/characters/gopnik.glb
fi
fetch_glb https://grab3d.com/dl/elderly-man-rigged/elderly-man-rigged.glb assets/characters/bomj.glb
fetch_glb https://grab3d.com/dl/man-rigged/man-rigged.glb assets/characters/gopnik.glb
