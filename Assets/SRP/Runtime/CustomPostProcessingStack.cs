using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Post-Processing Stack")]
public class CustomPostProcessingStack : ScriptableObject
{
    [SerializeField, Range(0, 10)]
    int blurStrength = 0;
    [SerializeField]
    bool depthStripes = false;
    [SerializeField]
    bool toneMapping = false;
    [SerializeField, Range(1f, 100f)]
    float toneMappingRange = 100f;

    public bool NeedsDepth
    {
        get
        {
            return depthStripes;
        }
    }

    static int mainTexId = Shader.PropertyToID("_MainTex");
    static int tempTexId = Shader.PropertyToID("_PostProcessingStackTempTex");
    static int depthTexId = Shader.PropertyToID("_DepthTex");
    static int resolvedTexId = Shader.PropertyToID("_PostProcessingStackResolvedTex");

    enum Pass { Copy, Blur, DepthStrips, ToneMapping };

    static Mesh fullScreenTriangle;
    static Material material;

    static void InitializeStatic()
    {
        if (fullScreenTriangle) return;

        fullScreenTriangle = new Mesh {
            name = "Post-Processing Stack Full-Screen Triangle",
            vertices = new Vector3[] {
                new Vector3(-1f, -1f, 0f),
                new Vector3(-1f,  3f, 0f),
                new Vector3( 3f, -1f, 0f)
            },
            triangles = new int[] { 0, 1, 2 },
        };
        fullScreenTriangle.UploadMeshData(true);

        material = new Material(Shader.Find("Hidden/Custom Pipeline/PostEffectStack")) {
            name = "Post-Processing Stack material",
            hideFlags = HideFlags.HideAndDontSave
        };
    }

    void Blit(CommandBuffer cb, RenderTargetIdentifier sourceId, RenderTargetIdentifier destinationId, Pass pass=Pass.Copy)
    {
        cb.SetGlobalTexture(mainTexId, sourceId);
        cb.SetRenderTarget(destinationId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cb.DrawMesh(fullScreenTriangle, Matrix4x4.identity, material, 0, (int)pass);
    }
    
    public void Render(CommandBuffer cb, int cameraColorId, int cameraDepthId, int width, int height)
    {
        //InitializeStatic();
        //Blur(cb, cameraColorId, cameraDepthId, width, height);
        //DepthStrips(cb, cameraColorId, cameraDepthId, width, height);
    }

    public void RenderAfterOpaque(CommandBuffer cb, int cameraColorId, int cameraDepthId, int width, int height, int samples, RenderTextureFormat format)
    {
        InitializeStatic();
        if (depthStripes)
        {
            DepthStrips(cb, cameraColorId, cameraDepthId, width, height, format);
        }
    }

    public void RenderAfterTransparent(CommandBuffer cb, int cameraColorId, int cameraDepthId, int width, int height, int samples, RenderTextureFormat format)
    {
        if(blurStrength > 0)
        {
            if (toneMapping || samples > 1)
            {
                // solved texture
                cb.GetTemporaryRT(resolvedTexId, width, height, 0, FilterMode.Bilinear);
                if (toneMapping)
                {
                    ToneMapping(cb, cameraColorId, resolvedTexId);
                } else
                {
                    Blit(cb, cameraColorId, resolvedTexId);
                }
                Blur(cb, resolvedTexId, width, height);
                cb.ReleaseTemporaryRT(resolvedTexId);
            } else
            {
                Blur(cb, cameraColorId, width, height);
            }
        }
        else if (toneMapping)
        {
            ToneMapping(cb, cameraColorId, BuiltinRenderTextureType.CameraTarget);
        }
        else
        {
            Blit(cb, cameraColorId, BuiltinRenderTextureType.CameraTarget);
        }
    }

    // blur effect
    void Blur(CommandBuffer cb, int cameraColorId, int width, int height)
    {
        cb.BeginSample("Blur");

        cb.GetTemporaryRT(tempTexId, width, height, 0, FilterMode.Bilinear);
        
        int passesLeft;
        for (passesLeft = blurStrength; passesLeft > 2; passesLeft -= 2)
        {
            Blit(cb, cameraColorId, tempTexId, Pass.Blur);
            Blit(cb, tempTexId, cameraColorId, Pass.Blur);
        }
        if (passesLeft > 0)
        {
            Blit(cb, cameraColorId, tempTexId, Pass.Blur);
            Blit(cb, tempTexId, BuiltinRenderTextureType.CameraTarget, Pass.Blur);
        }

        cb.ReleaseTemporaryRT(tempTexId);
        cb.EndSample("Blur");
    }

    // depth strips effect
    void DepthStrips(CommandBuffer cb, int cameraColorId, int cameraDepthId, int width, int height, RenderTextureFormat format)
    {
        cb.BeginSample("Depth Strips");

        cb.GetTemporaryRT(tempTexId, width, height, 0, FilterMode.Point, format);
        cb.SetGlobalTexture(depthTexId, cameraDepthId);
        Blit(cb, cameraColorId, tempTexId, Pass.DepthStrips);
        //Blit(cb, tempTexId, BuiltinRenderTextureType.CameraTarget);
        Blit(cb, tempTexId, cameraColorId);

        cb.ReleaseTemporaryRT(tempTexId);
        cb.EndSample("Depth Strips");
    }


    // tonemapping effect
    void ToneMapping(CommandBuffer cb, RenderTargetIdentifier sourceId, RenderTargetIdentifier destinationId)
    {
        cb.BeginSample("Tone Mapping");

        cb.SetGlobalFloat("_ReinhardModifier", 1f / (toneMappingRange * toneMappingRange));
  
        Blit(cb, sourceId, destinationId, Pass.ToneMapping);

        cb.ReleaseTemporaryRT(tempTexId);
        cb.EndSample("Tone Mapping");
    }
}