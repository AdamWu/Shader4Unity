using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Pipeline")]
public class CustomPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    bool dynamicBatching;
    [SerializeField]
    bool instancing;

    protected override RenderPipeline CreatePipeline()
    {
        return new CustomPipeline(dynamicBatching, instancing);
    }
}