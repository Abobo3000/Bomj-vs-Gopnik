"""Foot plants from the shot timing; layer concrete, knee, palm, grit and swipes."""
import json
import os
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

HERE=Path(__file__).resolve().parent
RATE=44100
mix=np.zeros((round(7.4*RATE),2))
rng=np.random.default_rng(978)
def place(t,signal,pan=0):
    start=round(t*RATE)
    gain=np.sqrt(np.array([1-pan,1+pan])*.5)
    tail=min(len(signal),len(mix)-start)
    if tail>0: mix[start:start+tail]+=signal[:tail,None]*gain

def noise(length, low, high):
    return sosfilt(butter(3,[low,high],fs=RATE,btype='bandpass',output='sos'),rng.normal(size=length))

def hit(at,volume,pitch,decay,pan=0,hardness=.5):
    t=np.arange(round(decay*7*RATE))/RATE
    body=np.sin(2*np.pi*(pitch*t+.60*(1-np.exp(-26*t))))
    impulse=(1-np.exp(-1500*t))*(body*np.exp(-t/decay)+hardness*noise(len(t),450,9800)*np.exp(-t/(decay*.36)))
    place(at,volume*impulse,pan)

def brush(at,duration,level,band,pan):
    t=np.arange(round(RATE*duration))/RATE
    place(at,level*noise(len(t),*band)*np.sin(np.pi*t/duration)**1.5,pan)

samples=sorted((HERE.parents[3]/'BPG2/Assets/EinarMotionGPT3/PlayableRun30/Footsteps').glob('gravel*.wav'))
for i,frame in enumerate([3,14,26,40,56,69,114,117,130,141,153,164,176,187,199,210]):
    with wave.open(str(samples[i%len(samples)])) as f:
        assert (f.getnchannels(),f.getframerate())==(1,RATE)
        wavelet=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)
    level=.19 if frame in [69,114] else .27
    place(frame/30,level*wavelet/max(abs(wavelet)),(-1)**i*.18)
    hit(frame/30,.09,79,.043,(-1)**i*.15)
contact=json.loads((HERE.parent/'shoulder-breach/Contact.json').read_text())['seconds']
hit(contact,.99,43,.20,-.12,1.8)
hit(contact+.022,.51,68,.088,.15,1.1)
brush(contact+.026,.58,.24,(70,2100),-.14)
for at in sorted(rng.uniform(contact+.02,3.75,75)):
    hit(at,rng.uniform(.018,.14)*np.exp(-(at-contact)*.55),rng.uniform(120,650),rng.uniform(.016,.07),rng.uniform(-.85,.85),1.1)
hit(2.72,.33,63,.102,-.22)
hit(2.84,.25,104,.071,.23)
brush(2.62,.52,.17,(220,4800),.25)
brush(3.44,.29,.09,(400,4300),.12)
for at in [4.23,5.31]:
    brush(at-.12,.22,.19,(660,5300),.32)
    hit(at,.19,375,.034,.39,1.4)
    hit(at+.49,.10,518,.028,.78,.92)
# A brief gallery reflection connects the separate impacts to the same room.
dry=mix.copy()
for delay,gain in [(0.054,.095),(.091,.056),(.171,.026)]:
    n=round(delay*RATE);mix[n:]+=gain*dry[:-n,::-1]
mix*=.92/max(np.max(np.abs(mix)),.001)
with wave.open(str(Path(os.environ['TEMP'])/'einar-player-recovery.wav'),'wb') as out:
    out.setparams((2,2,RATE,0,'NONE','not compressed'))
    out.writeframes((mix*32767).astype('<i2').tobytes())
