using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Pipeline")]
public class CustomPipelineAsset : RenderPipelineAsset {

    protected override RenderPipeline CreatePipeline()
    {
        return new CustomPipeline();
    }
}