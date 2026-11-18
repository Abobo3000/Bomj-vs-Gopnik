using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

public static class EinarWallShot
{
    const float WallZ = 5.1f;
    [Serializable] class Track { public Vector3[] points; }
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

    static List<Shard> Wall(Material[] faces, Material core)
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
            var mesh=new Mesh(); mesh.SetVertices(verts); mesh.subMeshCount=2;
            mesh.SetTriangles(front,0); mesh.SetTriangles(sides,1); mesh.RecalculateNormals(); mesh.RecalculateBounds();
            var go=new GameObject("Concrete fragment",typeof(MeshFilter),typeof(MeshRenderer));
            go.GetComponent<MeshFilter>().sharedMesh=mesh;
            go.GetComponent<MeshRenderer>().sharedMaterials=new[]{faces[Random.Range(0,faces.Length)],core};
            var start=new Vector3(s.x,s.y,WallZ); go.transform.position=start;
            var offset=s-new Vector2(0,1.12f);
            float radius=new Vector2(offset.x/.98f,offset.y/1.42f).magnitude;
            if(radius<1.13f)
                shards.Add(new Shard{body=go.transform,start=start, radius=.16f,
                    delay=radius*.07f, velocity=new Vector3(Mathf.Sign(s.x)*Random.Range(2.1f,4.5f),
                    Random.Range(1.2f,3.8f)+offset.y*.75f,Random.Range(2.0f,4.0f)),
                    spin=Random.onUnitSphere*Random.Range(160,440)});
        }
        return shards;
    }

    public static void Render() => RenderShot(false);
    public static void RenderPlayer() => RenderShot(true);

    static void RenderShot(bool playerView)
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
        var shards=Wall(faces,Surface("Fracture",new Color(.32f,.29f,.25f)));
        var sun=new GameObject("Key").AddComponent<Light>(); sun.type=LightType.Directional;
        sun.transform.rotation=Quaternion.Euler(43,-155,0); sun.intensity=2.4f; sun.shadows=LightShadows.Soft;
        var rim=new GameObject("Backlight").AddComponent<Light>(); rim.type=LightType.Directional;
        rim.transform.rotation=Quaternion.Euler(23,25,0); rim.intensity=1.15f; rim.color=new Color(.70f,.82f,1);
        var actor=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/EinarFull/PlayablePrefab/Einar.prefab"));
        const string folder="Assets/EinarMotionGPT3/SustainedSprints/AltBuild/";
        actor.GetComponent<Animator>().enabled=false;
        var rig=actor.transform.Find("RIG-einar deform transforms");
        var bytes=File.ReadAllBytes(folder+"Motion.bytes");
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
        var track=JsonUtility.FromJson<Track>(File.ReadAllText(folder+"Camera.json")).points;
        var cam=new GameObject("Shot camera").AddComponent<Camera>();
        cam.aspect=9f/16; cam.fieldOfView=38; cam.clearFlags=CameraClearFlags.SolidColor;
        cam.backgroundColor=new Color(.19f,.24f,.30f);
        int w=playerView?1280:720,h=playerView?720:1280;
        cam.aspect=(float)w/h;
        if(playerView) cam.fieldOfView=51;
        var rt=new RenderTexture(w,h,24); rt.Create();
        var image=new Texture2D(w,h,TextureFormat.RGB24,false);
        string output=Path.Combine(Path.GetTempPath(),playerView?"einar-wall-player-frames":"einar-wall-unity-frames");
        Directory.CreateDirectory(output);
        for(int frame=0;frame<150;frame++)
        {
            float t=frame/30f;
            // Ramp into slow motion at the breach, then return to full speed.
            float action=Mathf.Min(t,1.48f)+Mathf.Clamp(t-1.48f,0,1.65f)*.32f+Mathf.Max(0,t-3.13f);
            
            float f=action*30; int n=Mathf.FloorToInt(f);
            for(int i=0;i<channelCount;i++)
            {
                int a=(n*channelCount+i)*10,b=a+channelCount*10;
                var bone=rig.GetChild(i);
                bone.SetLocalPositionAndRotation(Vector3.Lerp(V(a),V(b),f-n),Quaternion.Slerp(Q(a+3),Q(b+3),f-n));
                bone.localScale=Vector3.Lerp(V(a+7),V(b+7),f-n);
            }
            for(int i=0;i<skins.Length;i++) { skins[i].BakeMesh(baked[i]); baked[i].RecalculateBounds(); }
            var focus=Vector3.Lerp(track[n],track[n+1],f-n);
            foreach(var sh in shards) {
                float dt=Mathf.Max(0,action-1.44f-sh.delay);
                float landing=(sh.velocity.y+Mathf.Sqrt(sh.velocity.y*sh.velocity.y+19.62f*Mathf.Max(0,sh.start.y-sh.radius)))/9.81f;
                float flight=Mathf.Min(dt,landing), slide=Mathf.Max(0,dt-landing);
                Vector3 pos=sh.start+sh.velocity*flight+Vector3.down*4.905f*flight*flight;
                pos+=new Vector3(sh.velocity.x,0,sh.velocity.z)*(.21f*(1-Mathf.Exp(-4*slide)));
                sh.body.SetPositionAndRotation(pos,Quaternion.Euler(sh.spin*(flight+.18f*(1-Mathf.Exp(-4*slide)))));
            }
            if(playerView) {
                cam.transform.position=focus+new Vector3(.53f,1.72f,-2.42f);
                cam.transform.LookAt(focus+new Vector3(.35f,1.12f,1.1f));
            } else if(t<1.18f) {
                cam.transform.position=focus+new Vector3(-2.45f,1.04f,1.35f);
                cam.transform.LookAt(focus+new Vector3(0,1.02f,.25f));
            } else {
                float cz=Mathf.Max(WallZ+3.5f,focus.z+3.30f);
                cam.transform.position=new Vector3(.17f,1.0f,cz);
                cam.transform.LookAt(new Vector3(0,1.02f,focus.z));
            }
            RenderPipeline.SubmitRenderRequest(cam,new UniversalRenderPipeline.SingleCameraRequest{destination=rt});
            RenderTexture.active=rt; image.ReadPixels(new Rect(0,0,w,h),0,0); image.Apply(); RenderTexture.active=null;
            File.WriteAllBytes(Path.Combine(output,frame.ToString("D4")+".jpg"),image.EncodeToJPG(96));
        }
        rt.Release();
        Debug.Log("Completed Einar wall shot: "+output);
    }
}

