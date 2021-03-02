using UnityEngine;
using UnityEngine.Rendering;

public class CustomPipeline : RenderPipeline
{
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    static ShaderTagId[] legacyShaderTagIds = {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };

    CommandBuffer cameraBuffer = new CommandBuffer { name = "Render Camera" };

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        for(int i = 0; i < cameras.Length; i ++)
        {
            Render(context, cameras[i]);
        }
    }

    void Render(ScriptableRenderContext context, Camera camera)
    {
        ScriptableCullingParameters cullingParameters;
        if (!camera.TryGetCullingParameters(out cullingParameters))
        {
            return;
        }

        // cull
        CullingResults cullingResults = context.Cull(ref cullingParameters);
        context.SetupCameraProperties(camera);

        // clear
        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.BeginSample("Render Camera");
        cameraBuffer.ClearRenderTarget((clearFlags & CameraClearFlags.Depth) != 0, (clearFlags & CameraClearFlags.Color) != 0, camera.backgroundColor);
        cameraBuffer.EndSample("Render Camera");
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        // draw oqaque mesh
        var sortingSettings = new SortingSettings(camera);
        var drawSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
        for (int i = 0; i < legacyShaderTagIds.Length; i ++)
        {
            drawSettings.SetShaderPassName(i+1, legacyShaderTagIds[i]);
        }
        var filterSetting = new FilteringSettings(RenderQueueRange.opaque);
        context.DrawRenderers(cullingResults, ref drawSettings, ref filterSetting);

        // draw skybox
        context.DrawSkybox(camera);

        // draw transparent mesh
        filterSetting = new FilteringSettings(RenderQueueRange.transparent);
        context.DrawRenderers(cullingResults, ref drawSettings, ref filterSetting);


        // commit
        context.Submit();
    }
}