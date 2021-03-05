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

    [SerializeField]
    bool dynamicBatching;
    [SerializeField]
    bool instancing;

    [SerializeField]
    ShadowMapSize shadowMapSize = ShadowMapSize._1024;

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new CustomPipeline(dynamicBatching, instancing, (int)shadowMapSize);
    }
}

