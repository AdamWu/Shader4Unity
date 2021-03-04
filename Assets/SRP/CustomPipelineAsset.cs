using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;


[CreateAssetMenu(menuName = "Rendering/Custom Pipeline")]
public class CustomPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    bool dynamicBatching;
    [SerializeField]
    bool instancing;

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new CustomPipeline(dynamicBatching, instancing);
    }
}

