using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

public static class EinarRecoveryShot
{
    const float WallZ = 5.1f;
    [Serializable] class Track { public Vector3[] points, hands; }
    [Serializable] class Contact { public float seconds, x, y, z; }
    class Shard
    {
        public Transform body;
        public Vector3 start, velocity, spin;
        public float delay, radius;
    }

    static Material Surface(string name, Color color, bool glowing = false)
    {
        var m = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = name };
        m.SetColor("_BaseColor", color);
        m.SetFloat("_Smoothness", .24f);
        if (glowing) { m.EnableKeyword("_EMISSION"); m.SetColor("_EmissionColor", color * 2); }
        return m;
    }

    static void Box(string name, Vector3 pos, Vector3 size, Material mat)
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
        go.name = name;
        go.transform.position = pos;
        go.transform.localScale = size;
        go.GetComponent<Renderer>().sharedMaterial = mat;
    }

    // Clip the wall rectangle against each Voronoi bisector. Adjacent pieces
    // share their border before impact and expose a darker core as they turn.
    static List<Vector2> Clip(List<Vector2> poly, Vector2 normal, Vector2 middle)
    {
        var result = new List<Vector2>();
        for (int i = 0; i < poly.Count; i++)
        {
            var a = poly[i]; var b = poly[(i + 1) % poly.Count];
            float da = Vector2.Dot(a - middle, normal), db = Vector2.Dot(b - middle, normal);
            if (da <= 0) result.Add(a);
            if ((da < 0) != (db < 0)) result.Add(Vector2.Lerp(a, b, da / (da - db)));
        }
        return result;
    }

    static List<Shard> Wall(Material[] faces, Material core, Contact contact)
    {
        var seeds = new List<Vector2>();
        for (int row = 0; row < 9; row++)
            for (int col = 0; col < 15; col++)
                seeds.Add(new Vector2(-3.6f + (col + Random.Range(.12f,.88f))*.48f,
                    (row + Random.Range(.12f,.88f))*.47f));
        var shards = new List<Shard>();
        foreach (var s in seeds)
        {
            var p = new List<Vector2>{new(-3.6f,0),new(3.6f,0),new(3.6f,4.23f),new(-3.6f,4.23f)};
            foreach(var other in seeds) if(other != s) p = Clip(p,other-s,(other+s)*.5f);
            var verts = new List<Vector3>(); var front = new List<int>(); var sides = new List<int>();
            void Triangle(Vector3 a, Vector3 b, Vector3 c, List<int> indices)
            {
                indices.Add(verts.Count); verts.Add(a); indices.Add(verts.Count); verts.Add(b);
                indices.Add(verts.Count); verts.Add(c);
            }
            for(int i=0;i<p.Count;i++)
            {
                Vector3 a=p[i]-s,b=p[(i+1)%p.Count]-s, d=Vector3.back*.23f;
                Triangle(Vector3.zero,a,b,front); Triangle(d,b+d,a+d,front);
                Triangle(a,a+d,b+d,sides); Triangle(a,b+d,b,sides);
            }
            var mesh=new Mesh(); mesh.SetVertices(verts); mesh.SetUVs(0,verts.ConvertAll(v=>new Vector2(v.x+s.x,v.y+s.y))); mesh.subMeshCount=2;
            mesh.SetTriangles(front,0); mesh.SetTriangles(sides,1); mesh.RecalculateNormals(); mesh.RecalculateBounds();
            var go=new GameObject("Concrete fragment",typeof(MeshFilter),typeof(MeshRenderer));
            go.GetComponent<MeshFilter>().sharedMesh=mesh;
            go.GetComponent<MeshRenderer>().sharedMaterials=new[]{faces[Random.Range(0,faces.Length)],core};
            var start=new Vector3(s.x,s.y,WallZ); go.transform.position=start;
            var offset=s-new Vector2(0,1.12f);
            float radius=new Vector2(offset.x/.98f,offset.y/1.42f).magnitude;
            if(radius<1.13f)
                shards.Add(new Shard{body=go.transform,start=start, radius=.16f,
                    delay=Vector2.Distance(s,new Vector2(contact.x,contact.y))*.034f, velocity=new Vector3(Mathf.Sign(s.x)*Random.Range(2.1f,4.5f),
                    Random.Range(1.2f,3.8f)+offset.y*.75f,Random.Range(2.0f,4.0f)),
                    spin=Random.onUnitSphere*Random.Range(160,440)});
        }
        return shards;
    }

    // Soft dust billboards stay near the fracture and dissipate after the runner passes.
    sealed class BreachDust
    {
        readonly Transform[] cards=new Transform[48];
        readonly Vector3[] origin=new Vector3[48], drift=new Vector3[48];
        readonly float[] delay=new float[48], size=new float[48];
        readonly Material[] materials=new Material[48];
        public BreachDust(float x,float y,float z)
        {
            var texture=new Texture2D(64,64,TextureFormat.RGBA32,false);
            for(int v=0;v<64;v++) for(int u=0;u<64;u++) {
                float dx=(u-31.5f)/31.5f,dy=(v-31.5f)/31.5f;
                float edge=Mathf.Clamp01(1-dx*dx-dy*dy);
                float noise=Mathf.PerlinNoise(u*.081f,v*.081f);
                texture.SetPixel(u,v,new Color(1,1,1,edge*edge*noise));
            }
            texture.Apply();
            for(int i=0;i<cards.Length;i++) {
                var card=GameObject.CreatePrimitive(PrimitiveType.Quad);
                cards[i]=card.transform;
                var m=new Material(Shader.Find("Universal Render Pipeline/Unlit"));
                m.SetTexture("_BaseMap",texture);
                m.SetFloat("_Surface",1); m.SetFloat("_SrcBlend",5); m.SetFloat("_DstBlend",10);
                m.SetFloat("_ZWrite",0); m.SetFloat("_Cull",0);
                m.EnableKeyword("_SURFACE_TYPE_TRANSPARENT"); m.renderQueue=3000;
                var renderer=card.GetComponent<Renderer>();
                renderer.shadowCastingMode=ShadowCastingMode.Off; renderer.sharedMaterial=m; materials[i]=m;
                float side=Random.Range(-.72f,.72f);
                origin[i]=new Vector3(x+side,y+Random.Range(-.72f,.77f),z+.1f);
                drift[i]=new Vector3(side*Random.Range(1.5f,3.1f),Random.Range(-.75f,1.35f),Random.Range(.8f,3f));
                delay[i]=Random.Range(.015f,.19f); size[i]=Random.Range(.36f,.98f);
            }
        }
        public void Sample(float time, Camera camera)
        {
            for(int i=0;i<cards.Length;i++) {
                float age=time-delay[i];
                bool visible=age>0 && age<1.5f;
                cards[i].gameObject.SetActive(visible);
                if(!visible) continue;
                float travel=1-Mathf.Exp(-age*2.25f);
                cards[i].SetPositionAndRotation(origin[i]+drift[i]*travel,camera.transform.rotation);
                cards[i].localScale=Vector3.one*(.12f+size[i]*travel);
                float alpha=Mathf.Min(1,age*16)*(1-age/1.5f)*.72f;
                materials[i].SetColor("_BaseColor",new Color(.62f,.59f,.54f,alpha));
            }
        }
    }



    [MenuItem("BPG2/Einar/Record player breach and recovery")]
    public static void RenderPlayerRecovery()
    {
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
        Random.InitState(441);
        QualitySettings.skinWeights=SkinWeights.Unlimited;
        RenderSettings.ambientMode=AmbientMode.Flat;
        RenderSettings.ambientLight=new Color(.47f,.52f,.62f);
        var floor=Surface("Graphite tile",new Color(.28f,.32f,.35f));
        var seam=Surface("Recessed joint",new Color(.12f,.15f,.18f));
        var iron=Surface("Steel",new Color(.19f,.23f,.26f));
        var amber=Surface("Amber guide",new Color(.94f,.42f,.095f),true);
        Box("Slab",new Vector3(0,-.15f,9),new Vector3(12,.28f,45),floor);
        for(int z=-12;z<31;z+=2) {
            Box("Expansion joint",new Vector3(0,-.009f,z),new Vector3(9,.004f,.015f),seam);
            foreach(int sign in new[]{-1,1}) {
                if(z%4==0) Box("Bay upright",new Vector3(sign*3.73f,2.4f,z),new Vector3(.22f,4.8f,.27f),iron);
                Box("Floor marker",new Vector3(sign*1.65f,-.006f,z),new Vector3(.055f,.008f,.84f),amber);
            }
        }
        foreach(int sign in new[]{-1,1}) {
            Box("Gallery",new Vector3(sign*3.95f,2.3f,8),new Vector3(.3f,4.6f,42),seam);
            Box("Guide light",new Vector3(sign*3.77f,2.65f,9),new Vector3(.05f,.045f,42),amber);
        }
        var faces=new Material[5];
        for(int i=0;i<faces.Length;i++) faces[i]=Surface("Cast concrete",new Color(.53f,.52f,.49f)*(1+i*.013f));
        var source=Path.GetFullPath("../assets/characters/einar/shoulder-breach");
        var contact=JsonUtility.FromJson<Contact>(File.ReadAllText(Path.Combine(source,"Contact.json")));
        var grain=new Texture2D(256,256,TextureFormat.RGBA32,true);
        var texels=new Color32[256*256];
        for(int i=0;i<texels.Length;i++) {
            int x=i%256,y=i/256;
            float mottling=Mathf.PerlinNoise(x*.043f,y*.043f);
            byte value=(byte)Mathf.Clamp(167+45*mottling+Random.Range(-14,15),0,255);
            texels[i]=new Color32(value,value,value,255);
        }
        grain.SetPixels32(texels); grain.Apply();
        foreach(var mat in faces) mat.SetTexture("_BaseMap",grain);
        for(int z=-6;z<27;z+=4)
            Box("Concrete lintel",new Vector3(0,3.98f,z),new Vector3(7.9f,.22f,.41f),iron);
        var shards=Wall(faces,Surface("Fracture",new Color(.32f,.29f,.25f)),contact);
        var grit=new Transform[54];
        for(int i=0;i<grit.Length;i++) {
            grit[i]=UnityEngine.Object.Instantiate(shards[i%shards.Count].body);
            grit[i].name="Concrete spall"; grit[i].localScale=Vector3.one*Random.Range(.045f,.21f);
        }
        var dust=new BreachDust(contact.x,contact.y,WallZ);
        var sun=new GameObject("Key").AddComponent<Light>(); sun.type=LightType.Directional;
        sun.transform.rotation=Quaternion.Euler(43,-155,0); sun.intensity=2.4f; sun.shadows=LightShadows.Soft;
        var rim=new GameObject("Backlight").AddComponent<Light>(); rim.type=LightType.Directional;
        rim.transform.rotation=Quaternion.Euler(23,25,0); rim.intensity=1.15f; rim.color=new Color(.70f,.82f,1);
        var actor=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/EinarFull/PlayablePrefab/Einar.prefab"));
        actor.GetComponent<Animator>().enabled=false;
        var rig=actor.transform.Find("RIG-einar deform transforms");
        var recovery=Path.GetFullPath("../assets/characters/einar/breach-recovery");
        var bytes=File.ReadAllBytes(Path.Combine(recovery,"Recovery.bytes"));
        int channelCount=BitConverter.ToInt32(bytes,4);
        if (channelCount!=rig.childCount) throw new InvalidDataException("Unexpected Einar channels");
        var samples=new float[(bytes.Length-8)/4];
        Buffer.BlockCopy(bytes,8,samples,0,bytes.Length-8);
        Vector3 V(int i)=>new Vector3(samples[i],samples[i+1],samples[i+2]);
        Quaternion Q(int i)=>new Quaternion(samples[i],samples[i+1],samples[i+2],samples[i+3]);
        var skins=actor.GetComponentsInChildren<SkinnedMeshRenderer>();
        var baked=new Mesh[skins.Length];
        for(int i=0;i<skins.Length;i++)
        {
            var skin=skins[i];
            var copy=new GameObject(skin.name+" capture mesh");
            copy.transform.SetParent(skin.transform,false);
            baked[i]=new Mesh(); baked[i].MarkDynamic();
            copy.AddComponent<MeshFilter>().sharedMesh=baked[i];
            copy.AddComponent<MeshRenderer>().sharedMaterials=skin.sharedMaterials;
            skin.enabled=false;
        }
        var blocking=JsonUtility.FromJson<Track>(File.ReadAllText(Path.Combine(recovery,"Blocking.json")));
        var track=blocking.points;
        var cam=new GameObject("Shot camera").AddComponent<Camera>();
        cam.aspect=16f/9; cam.fieldOfView=52; cam.clearFlags=CameraClearFlags.SolidColor;
        cam.backgroundColor=new Color(.19f,.24f,.30f);
        const int w=1600,h=900;
        var rt=new RenderTexture(w,h,24); rt.Create();
        var image=new Texture2D(w,h,TextureFormat.RGB24,false);
        string output=Path.Combine(Path.GetTempPath(),"einar-player-recovery-v2");
        Directory.CreateDirectory(output);
        for(int frame=0;frame<track.Length;frame++)
        {
            float t=frame/30f;
            float action=t;
            int n=frame; float f=n;
            for(int i=0;i<channelCount;i++)
            {
                int a=(n*channelCount+i)*10,b=a;
                var bone=rig.GetChild(i);
                bone.SetLocalPositionAndRotation(Vector3.Lerp(V(a),V(b),f-n),Quaternion.Slerp(Q(a+3),Q(b+3),f-n));
                bone.localScale=Vector3.Lerp(V(a+7),V(b+7),f-n);
            }
            for(int i=0;i<skins.Length;i++) { skins[i].BakeMesh(baked[i]); baked[i].RecalculateBounds(); }
            var focus=track[n];
            foreach(var sh in shards) {
                float dt=Mathf.Max(0,action-contact.seconds-sh.delay);
                float landing=(sh.velocity.y+Mathf.Sqrt(sh.velocity.y*sh.velocity.y+19.62f*Mathf.Max(0,sh.start.y-sh.radius)))/9.81f;
                float flight=Mathf.Min(dt,landing), slide=Mathf.Max(0,dt-landing);
                Vector3 pos=sh.start+sh.velocity*flight+Vector3.down*4.905f*flight*flight;
                pos+=new Vector3(sh.velocity.x,0,sh.velocity.z)*(.21f*(1-Mathf.Exp(-4*slide)));
                sh.body.SetPositionAndRotation(pos,Quaternion.Euler(sh.spin*(flight+.18f*(1-Mathf.Exp(-4*slide)))));
            }
            // Secondary chips fall from the lintel. Two pass through the
            // sampled hand position, then take an outward trajectory at contact.
            for(int i=0;i<grit.Length;i++) {
                bool parried=i<2;
                float eventTime=i==0?4.23f:5.31f;
                float age=t-(parried?eventTime:contact.seconds+.004f*(i%18));
                var chip=grit[i];
                chip.gameObject.SetActive(parried?age>-.59f && age<1.22f:age>0 && age<2.4f);
                if(!chip.gameObject.activeSelf) continue;
                Vector3 pos;
                if(parried) {
                    var at=blocking.hands[Mathf.RoundToInt(eventTime*30)];
                    float sign=i==0?1:-1;
                    pos=at+(age<0?new Vector3(.35f*sign,-5.9f,-1.6f):new Vector3(3.6f,1.65f,3.9f))*age;
                    pos.y-=4.905f*age*age;
                } else {
                    float dir=i*2.39996f;
                    pos=new Vector3(contact.x,contact.y,WallZ)+new Vector3(Mathf.Sin(dir)*(1.3f+i%5),1.6f+i%6*.53f,Mathf.Cos(dir)*1.4f+2.5f)*age;
                    pos.y-=4.905f*age*age;
                }
                pos.y=Mathf.Max(.035f,pos.y);
                chip.SetPositionAndRotation(pos,Quaternion.Euler(i*17+210*age,145*age,i*53));
            }
            float low=Mathf.SmoothStep(0,1,Mathf.InverseLerp(2.12f,2.93f,t))*
                      (1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(3.34f,4.22f,t)));
            float shakeAge=Mathf.Max(0,t-contact.seconds);
            float jolt=t<contact.seconds?0:.058f*Mathf.Exp(-shakeAge*10)*Mathf.Sin(shakeAge*62);
            cam.transform.position=focus+new Vector3(.59f,1.80f-low*.34f+jolt,-2.70f);
            cam.transform.LookAt(focus+new Vector3(.29f,.95f-low*.31f,1.05f));
            dust.Sample(action-contact.seconds,cam);
            RenderPipeline.SubmitRenderRequest(cam,new UniversalRenderPipeline.SingleCameraRequest{destination=rt});
            RenderTexture.active=rt; image.ReadPixels(new Rect(0,0,w,h),0,0); image.Apply(); RenderTexture.active=null;
            File.WriteAllBytes(Path.Combine(output,frame.ToString("D4")+".jpg"),image.EncodeToJPG(96));
        }
        rt.Release();
        Debug.Log("Completed Einar wall shot: "+output);
    }
}
