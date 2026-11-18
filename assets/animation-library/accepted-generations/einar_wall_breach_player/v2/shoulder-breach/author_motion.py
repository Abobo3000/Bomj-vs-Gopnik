"""Author the shoulder-charge take on the native Einar deformation channels."""
import array
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "BPG2/Assets/EinarMotionGPT3/SustainedSprints/AltBuild"
SKIN = ROOT / "BPG2/Assets/EinarFull/EinarFullSkin.bytes"
OUT = Path(__file__).resolve().parent


def skin_centres():
    data = SKIN.read_bytes()
    groups, channels = struct.unpack_from("<ii", data)
    cursor = 8
    def string():
        nonlocal cursor
        length, = struct.unpack_from("<i", data, cursor)
        cursor += 4 + length
        return data[cursor-length:cursor].decode()
    names = [string() for _ in range(channels)]
    sums = [[0., 0., 0., 0.] for _ in names]
    guard=[]
    for _ in range(groups):
        mesh_name=string()
        string()
        verts, indices = struct.unpack_from("<ii", data, cursor)
        cursor += 8 + indices * 4
        for i in range(verts):
            count = data[cursor+32]
            if mesh_name=="GEO-shoulder_guard":
                xyz=struct.unpack_from("<fff",data,cursor)
                influences=[struct.unpack_from("<if",data,cursor+33+k*8) for k in range(count)]
                guard.append((xyz,influences))
            if i % 8 == 0:
                xyz = struct.unpack_from("<fff", data, cursor)
                for k in range(count):
                    bone, weight = struct.unpack_from("<if", data, cursor+33+k*8)
                    sums[bone][3] += weight
                    for axis in range(3):
                        sums[bone][axis] += xyz[axis]*weight
            cursor += 33 + count*8
    assert cursor == len(data)
    return names, [tuple(v/t[3] for v in t[:3]) if t[3] else (0.,0.,0.) for t in sums], guard


def mul(a,b):
    x,y,z,w=a
    i,j,k,l=b
    return (w*i+x*l+y*k-z*j,w*j-x*k+y*l+z*i,w*k+x*j-y*i+z*l,w*l-x*i-y*j-z*k)


def rotate(q,v):
    return mul(mul(q,(*v,0)),(-q[0],-q[1],-q[2],q[3]))[:3]


def axis(a,angle):
    v=[0.,0.,0.,math.cos(angle/2)]
    v[a]=math.sin(angle/2)
    return tuple(v)


def smooth(x):
    x=max(0.,min(1.,x))
    return x*x*(3-2*x)


def blend(a,b,k):
    return tuple(x+(y-x)*k for x,y in zip(a,b))


def charge():
    names, centres, guard=skin_centres()
    raw=(SOURCE/"Motion.bytes").read_bytes()
    frames,count=struct.unpack_from("<ii",raw)
    assert count==len(names)
    motion=array.array("f"); motion.frombytes(raw[8:])
    track=json.loads((SOURCE/"Camera.json").read_text())["points"]
    def pose(frame,i):
        n=(frame*count+i)*10
        return tuple(motion[n:n+10])
    def point(p,centre):
        d=rotate(p[3:7],tuple(v*s for v,s in zip(centre,p[7:])))
        return tuple(a+b for a,b in zip(d,p[:3]))

    result=array.array("f")
    for f in range(126):
        # Two strides to gather, a short compression, then gradually open the stride.
        brace=smooth((f-25)/16)*(1-smooth((f-46)/22))
        recoil=smooth((f-42)/3)*(1-smooth((f-45)/9))
        for i,(name,centre) in enumerate(zip(names,centres)):
            p=pose(f,i)
            lower=any(k in name.lower() for k in ("thigh","knee","foot","toe","boot","pants","shin"))
            upper=0. if lower else (.48 if name=="DEF-Spine" else 1.)
            k=brace*upper
            if k:
                # Hold a compact upper-body phase while the legs continue the original stride.
                # Resample one coherent pose for all attachments. Blending transforms
                # from distant frames can separate rigid parts whose pivots differ.
                upper_frame=min(f,40)+max(0,f-40)*smooth((f-45)/23)
                phase=f+(upper_frame-f)*upper
                base=int(phase)
                frac=phase-base
                a,b=pose(base,i),pose(base+1,i)
                offset=blend(a[:3],b[:3],frac)
                xyz=tuple(offset[d]+track[f][c]-((1-frac)*track[base][c]+frac*track[base+1][c])
                          for d,c in enumerate("xyz"))
                qa,qb=a[3:7],b[3:7]
                if sum(x*y for x,y in zip(qa,qb))<0: qb=tuple(-x for x in qb)
                q=blend(qa,qb,frac)
                length=math.sqrt(sum(x*x for x in q))
                q=tuple(v/length for v in q)
                pivot=(track[f]["x"],.91,track[f]["z"])
                # Positive yaw turns the anatomical left shoulder toward travel (+Z).
                rot=mul(axis(1,math.radians(53*k)),mul(axis(2,math.radians(12*k)),axis(0,math.radians(18*k))))
                xyz=rotate(rot,tuple(v-o for v,o in zip(xyz,pivot)))
                xyz=[v+o for v,o in zip(xyz,pivot)]
                xyz[1]-=.095*k+.035*recoil*upper
                xyz[2]-=.10*recoil*upper
                p=(*xyz,*mul(rot,q),*p[7:])
            result.extend(p)
    # Intersect the actual leading surface of the shoulder guard with the rear wall plane.
    near=5.1-.23
    previous=None
    for f in range(32,49):
        transforms={}
        vertices=[]
        for xyz,influences in guard:
            pos=[0.,0.,0.]
            for i,w in influences:
                if i not in transforms:
                    off=(f*count+i)*10
                    transforms[i]=result[off:off+10]
                v=point(transforms[i],xyz)
                for j in range(3): pos[j]+=v[j]*w
            vertices.append(pos)
        front=max(vertices,key=lambda v:v[2])
        if previous is not None and previous[2]<near<=front[2]:
            k=(near-previous[2])/(front[2]-previous[2])
            impact=blend(previous,front,k)
            break
        previous=front
    else: raise ValueError("Shoulder guard does not cross the wall")
    (OUT/"ShoulderCharge.bytes").write_bytes(struct.pack("<ii",126,count)+result.tobytes())
    contact={"seconds":(f-1+k)/30,"x":impact[0],"y":impact[1],"z":near}
    (OUT/"Contact.json").write_text(json.dumps(contact,indent=2)+"\n")
    print(contact)


if __name__=="__main__":
    charge()
