using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;


[CreateAssetMenu(menuName = "Rendering/Custom Pipeline")]
public class CustomPipelineAsset : RenderPipelineAsset
{
    public enum ShadowMapSize
    {
        _256 = 256,
        _512 = 512,
        _1024 = 1024,
        _2048 = 2048,
        _4096 = 4096
    }
    public enum ShadowCascades
    {
        Zero = 0,
        Two = 2,
        Four = 4
    }

    public enum MSAAMode
    {
        Off = 1,
        _2x = 2,
        _4x = 4,
        _8x = 8
    }

    [SerializeField]
    bool dynamicBatching = false;
    [SerializeField]
    bool instancing = false;

    [SerializeField]
    CustomPostProcessingStack defaultStack;

    [SerializeField]
    ShadowMapSize shadowMapSize = ShadowMapSize._1024;
    [SerializeField]
    float shadowDistance = 100f;
    [SerializeField, Range(0.01f, 2f)]
    float shadowFadeRange = 1f;
    [SerializeField]
    ShadowCascades shadowCascades = ShadowCascades.Four;
    [SerializeField, HideInInspector]
    float twoCascadesSplit = 0.25f;
    [SerializeField, HideInInspector]
    Vector3 fourCascadesSplit = new Vector3(0.067f, 0.2f, 0.467f);
    
    [SerializeField, Range(0.25f, 2f)]
    float renderScale = 1f;
    [SerializeField]
    MSAAMode MSAA = MSAAMode.Off;
    [SerializeField]
    bool allowHDR;

    protected override IRenderPipeline InternalCreatePipeline()
    {
        Vector3 shadowCascadeSplit = shadowCascades == ShadowCascades.Four ? fourCascadesSplit : new Vector3(twoCascadesSplit, 0);
        return new CustomPipeline(dynamicBatching, instancing, defaultStack,
            (int)shadowMapSize, shadowDistance, shadowFadeRange, (int)shadowCascades, shadowCascadeSplit,
            renderScale, (int)MSAA, allowHDR);
    }

    public bool HasShadowCascades
    {
        get
        {
            return shadowCascades != ShadowCascades.Zero;
        }
    }
}

