using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BloomEffect : MonoBehaviour
{
    // pass
    const int BoxDownPrefilterPass = 0;
    const int BoxDownPass = 1;
    const int BoxUpPass = 2;
    const int ApplyBloomPass = 3;
    const int DebugBloomPass = 4;

    public Shader bloomShader;
    [Range(0, 10)]
    public float intensity = 1;
    [Range(1, 16)]
    public int iterations = 4;
    [Range(0, 10)]
    public float threshold = 1;
    [Range(0, 1)]
    public float softThreshold = 0.5f;
    public bool debug;

    Material bloomMaterial = null;

    RenderTexture[] textures = new RenderTexture[16];


    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (bloomMaterial == null)
        {
            bloomMaterial = new Material(bloomShader);
            bloomMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        float knee = threshold * softThreshold;
        Vector4 filter;
        filter.x = threshold;
        filter.y = filter.x - knee;
        filter.z = 2f * knee;
        filter.w = 0.25f / (knee + 0.00001f);
        bloomMaterial.SetVector("_Filter", filter);
        bloomMaterial.SetFloat("_Intensity", Mathf.GammaToLinearSpace(intensity));

        int width = source.width/2;
        int height = source.height/2;
        RenderTextureFormat format = source.format;

        RenderTexture curDestination = textures[0] = RenderTexture.GetTemporary(width, height, 0, format);
        Graphics.Blit(source, curDestination, bloomMaterial, BoxDownPrefilterPass);
        RenderTexture curSource = curDestination;

        int i = 1;
        for (; i < iterations; i++)
        {
            width /= 2;
            height /= 2;
            if (height < 2) break;

            curDestination = textures[i] = RenderTexture.GetTemporary(width, height, 0, format);
            Graphics.Blit(curSource, curDestination, bloomMaterial, BoxDownPass);
            curSource = curDestination;
        }

        for (i-=2; i >=0; i--)
        {
            curDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(curSource, curDestination, bloomMaterial, BoxUpPass);
            RenderTexture.ReleaseTemporary(curSource);
            curSource = curDestination;
        }

        if(debug)
        {
            Graphics.Blit(curSource, destination, bloomMaterial, ApplyBloomPass);
        }
        else
        {
            bloomMaterial.SetTexture("_SourceTex", source);
            Graphics.Blit(curSource, destination, bloomMaterial, ApplyBloomPass);
        }
        RenderTexture.ReleaseTemporary(curSource);
    }

}