"""Bake the shoulder impact, interrupted stride, three-point fall and debris parries."""
import json
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.spatial.transform import Rotation
from scipy.interpolate import PchipInterpolator

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent / 'shoulder-breach'))
from author_motion import skin_centres

def load(path):
    data = path.read_bytes()
    frames, channels = struct.unpack_from('<ii', data)
    return np.frombuffer(data, dtype='<f4', offset=8).reshape(frames, channels, 10)

def ease(a,b,t):
    x=np.clip((t-a)/(b-a),0,1)
    return x*x*(3-2*x)

def curve(keys):
    return PchipInterpolator(*zip(*keys))

def aim(a,b):
    a=a/np.linalg.norm(a); b=b/np.linalg.norm(b)
    cross=np.cross(a,b)
    return Rotation.from_rotvec(cross* (np.arctan2(np.linalg.norm(cross),np.dot(a,b))/max(1e-8,np.linalg.norm(cross))))

def main():
    names, centres, _ = skin_centres()
    bind=np.asarray(centres)
    run_folder=ROOT/'BPG2/Assets/EinarMotionGPT3/SustainedSprints/AltBuild'
    run=load(run_folder/'Motion.bytes')
    brace=load(HERE.parent/'shoulder-breach/ShoulderCharge.bytes')
    kneel=load(ROOT/'BPG2/Assets/EinarWaveKneel/WaveKneel.bytes')
    root=np.array([[p['x'],0,p['z']] for p in json.loads((run_folder/'Camera.json').read_text())['points']])
    arm=names.index('DEF-UpperArm.R')
    fore=names.index('DEF-Forearm.R')
    wrist=names.index('DEF-Wrist.R')
    head=names.index('DEF-Hat.R')
    fingers=[i for i,n in enumerate(names) if n.startswith('DEF-Finger') and n.endswith('.R')]
    arm_chain=[arm,fore,wrist]+fingers
    fore_chain=[fore,wrist]+fingers
    def points(p):
        return Rotation.from_quat(p[:,3:7]).apply(p[:,7:]*bind)+p[:,:3]
    def blend_pose(a,b,k):
        qa=a[:,3:7]; qb=b[:,3:7]
        q=qa*(1-k)+qb*np.where(np.sum(qa*qb,axis=1,keepdims=True)<0,-k,k)
        q/=np.linalg.norm(q,axis=1,keepdims=True)
        scale=(1-k)*a[:,7:]+k*b[:,7:]
        xyz=(1-k)*points(a)+k*points(b)-Rotation.from_quat(q).apply(scale*bind)
        return np.column_stack((xyz,q,scale))
    def turn(p,indices,pivot,rotation):
        p[indices,:3]=pivot+rotation.apply(p[indices,:3]-pivot)
        p[indices,3:7]=(rotation*Rotation.from_quat(p[indices,3:7])).as_quat()
    def hand_target(p,target,weight):
        if weight<=0: return
        def joint(index,bindpos):
            return p[index,:3]+Rotation.from_quat(p[index,3:7]).apply(p[index,7:]*bindpos)
        shoulder=joint(arm,[.167,1.465,.105])
        elbow=joint(fore,[.218,1.19,.185])
        hand=joint(wrist,[.26,.98,.30])
        goal=hand+(target-hand)*weight
        line=goal-shoulder
        length=np.linalg.norm(line); line/=max(.00001,length)
        upper=np.linalg.norm(elbow-shoulder); lower=np.linalg.norm(hand-elbow)
        dist=np.clip(length,abs(upper-lower)+.003,upper+lower-.008)
        along=(upper**2-lower**2+dist**2)/(2*dist)
        pole=np.array([.9,-.36,-.28]); pole-=np.dot(pole,line)*line
        pole/=max(.001,np.linalg.norm(pole))
        bend=shoulder+along*line+np.sqrt(max(0,upper**2-along**2))*pole
        r=aim(elbow-shoulder,bend-shoulder)
        turn(p,arm_chain,shoulder,r)
        new_hand=shoulder+r.apply(hand-shoulder)
        turn(p,fore_chain,bend,aim(new_hand-bend,shoulder+dist*line-bend))
    phase=curve([(0,0),(1.32,39.6),(1.48,42.1),(1.95,54),(2.32,61),(2.75,65),(3.24,67),(3.67,71),(4.15,81),(4.6,94.5),(7.4,178.5)])
    distance=curve([(0,0),(1.32,root[40,2]),(1.47,4.78),(1.75,5.37),(2.12,6.64),(2.45,7.48),(2.77,7.85),(3.08,7.93),(3.41,7.95),(3.75,8.15),(4.15,8.94),(4.64,10.55),(7.4,21.42)])
    fall_pitch=curve([(0,0),(1.79,0),(2.16,13),(2.47,33),(2.76,69),(2.9,77),(3.08,68),(3.35,42),(3.64,22),(4.05,5),(4.36,0),(7.4,0)])
    roll=curve([(0,0),(1.69,0),(2.22,-9),(2.84,-26),(3.12,-23),(3.68,5),(4.35,0),(7.4,0)])
    frames=[]; tracks=[]; hands=[]
    for frame in range(222):
        t=frame/30
        f=t*30 if t<=1.37 else max(41.1,float(phase(t)))
        a=int(f); k=f-a
        src=brace if a+1<len(brace) else run
        p=blend_pose(src[a],src[a+1],k)
        origin=root[a]*(1-k)+root[a+1]*k
        z=origin[2] if t<=1.37 else float(distance(t))+(root[41,2]-distance(1.37))*(1-ease(1.37,1.8,t))
        loc=np.array([origin[0]+.32*ease(1.9,2.88,t)-.25*ease(3.6,4.6,t),0,z])
        p[:,:3]+=loc-origin
        ground=ease(2.05,2.82,t)*(1-ease(3.31,4.22,t))
        if ground:
            crouch=kneel[round(155+65*ground)].astype(float)
            crouch[:,:3]+=loc+[0,0,.30]
            p=blend_pose(p,crouch,ground)
        if t>1.79:
            pivot=loc+np.array([0,.42*ground+.85*(1-ground),0])
            turn(p,slice(None),pivot,Rotation.from_euler('zx',[roll(t),fall_pitch(t)],degrees=True))
        if ground:
            # Land on the folded shin, then support the torso with the right palm.
            footpoints=points(p)[[names.index(n) for n in ['DEF-Foot.R','DEF-Foot.L','DEF-Knee.R','DEF-Knee.L','DEF-Toes.R','DEF-Toes.L']]]
            p[:,1]+=(.046-footpoints[:,1].min())*ground
        hand_target(p,loc+[.37,.09,.56],ease(2.18,2.77,t)*(1-ease(3.28,3.8,t)))
        for start in [4.14,5.22]:
            u=t-start
            strength=ease(-.31,-.05,u)*(1-ease(.22,.51,u))
            reach=ease(-.055,.16,u)
            target=points(p)[head]+np.array([-.16+.88*reach,-.12-.16*reach,.30-.08*reach])
            hand_target(p,target,strength)
        hands.append(points(p)[names.index('DEF-Finger_Index1.R')].tolist())
        frames.append(p); tracks.append(dict(zip('xyz',loc)))
    motion=np.asarray(frames,dtype='<f4')
    assert np.isfinite(motion).all()
    (HERE/'Recovery.bytes').write_bytes(struct.pack('<ii',*motion.shape[:2])+motion.tobytes())
    def vectors(v): return [dict(zip('xyz',a)) for a in v]
    (HERE/'Blocking.json').write_text(json.dumps(dict(points=tracks,hands=vectors(hands)),separators=(',',':')))
if __name__=='__main__': main()
