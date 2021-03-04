using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;

public class CustomPipeline : RenderPipeline
{
    static ShaderPassName unlitShaderTagId = new ShaderPassName("SRPDefaultUnlit");
    static ShaderPassName[] legacyShaderTagIds = {
        new ShaderPassName("Always"),
        new ShaderPassName("ForwardBase"),
        new ShaderPassName("PrepassBase"),
        new ShaderPassName("Vertex"),
        new ShaderPassName("VertexLMRGBM"),
        new ShaderPassName("VertexLM")
    };

    CommandBuffer cameraBuffer = new CommandBuffer { name = "Render Camera" };
    CommandBuffer shadowBuffer = new CommandBuffer { name = "Render Shadows" };

    CullResults cullingResults;

    bool enableDynamicBatching = false;
    bool enableInstancing = false;

    // lights
    const int maxVisibleLights = 16;
    static int visibleLightColorsId = Shader.PropertyToID("_VisibleLightColors");
    static int visibleLightDirectionsOrPositionsId = Shader.PropertyToID("_VisibleLightDirectionsOrPositions");
    static int visibleLightAttenuationsId = Shader.PropertyToID("_VisibleLightAttenuations");
    static int visibleLightSpotDirectionsId = Shader.PropertyToID("_VisibleLightSpotDirections");
    Vector4[] visibleLightColors = new Vector4[maxVisibleLights];
    Vector4[] visibleLightDirectionsOrPositions = new Vector4[maxVisibleLights];
    Vector4[] visisbleLightAtenuations = new Vector4[maxVisibleLights];
    Vector4[] visisbleLightSpotDirections = new Vector4[maxVisibleLights];

    // shadow
    RenderTexture shadowMap;
    static int shadowMapId = Shader.PropertyToID("_ShadowMap");
    static int worldToShadowMatrixId = Shader.PropertyToID("_WorldToShadowMatrix");

    public CustomPipeline(bool enableDynamicBatching, bool enableInstancing)
    {
        GraphicsSettings.lightsUseLinearIntensity = true;

        this.enableDynamicBatching = enableDynamicBatching;
        this.enableInstancing = enableInstancing;
    }

    public override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        base.Render(context, cameras);

        for (int i = 0; i < cameras.Length; i ++)
        {
            Render(context, cameras[i]);
        }
    }

    void Render(ScriptableRenderContext context, Camera camera)
    {
        ScriptableCullingParameters cullingParameters;
        if (!CullResults.GetCullingParameters(camera, out cullingParameters))
        {
            return;
        }

        // cull
        CullResults.Cull(ref cullingParameters, context, ref cullingResults);
        if (cullingResults.visibleLights.Count > 0)
        {
            ConfigureLights();
            RenderShadows(context);
        }

        // camear set
        context.SetupCameraProperties(camera);

        // clear
        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.BeginSample("Render Camera");
        cameraBuffer.ClearRenderTarget((clearFlags & CameraClearFlags.Depth) != 0, (clearFlags & CameraClearFlags.Color) != 0, camera.backgroundColor);
        
        // light constans
        cameraBuffer.SetGlobalVectorArray(visibleLightColorsId, visibleLightColors);
        cameraBuffer.SetGlobalVectorArray(visibleLightDirectionsOrPositionsId, visibleLightDirectionsOrPositions);
        cameraBuffer.SetGlobalVectorArray(visibleLightAttenuationsId, visisbleLightAtenuations);
        cameraBuffer.SetGlobalVectorArray(visibleLightSpotDirectionsId, visisbleLightSpotDirections);

        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        // draw oqaque mesh
        //var sortingSettings = new SortingSettings(camera);
        DrawRendererFlags drawFlags = DrawRendererFlags.None;
        if (enableDynamicBatching)
        {
            drawFlags = DrawRendererFlags.EnableDynamicBatching;
        }
        if (enableInstancing)
        {
            drawFlags |= DrawRendererFlags.EnableInstancing;
        }
        var drawSettings = new DrawRendererSettings(camera, unlitShaderTagId);
        drawSettings.flags = drawFlags;
        drawSettings.sorting.flags = SortFlags.CommonOpaque;
        drawSettings.rendererConfiguration = RendererConfiguration.PerObjectLightIndices8;
        
        for (int i = 0; i < legacyShaderTagIds.Length; i ++)
        {
            drawSettings.SetShaderPassName(i+1, legacyShaderTagIds[i]);
        }
        var filterSettings = new FilterRenderersSettings(true);
        filterSettings.renderQueueRange = RenderQueueRange.opaque;
        context.DrawRenderers(cullingResults.visibleRenderers, ref drawSettings, filterSettings);

        // draw skybox
        context.DrawSkybox(camera);

        // draw transparent mesh
        filterSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults.visibleRenderers, ref drawSettings, filterSettings);

        cameraBuffer.EndSample("Render Camera");

        // commit
        context.Submit();

        // release
        if (shadowMap)
        {
            RenderTexture.ReleaseTemporary(shadowMap);
            shadowMap = null;
        }
    }

    void ConfigureLights()
    {
        int i = 0;
        for (; i < cullingResults.visibleLights.Count; i ++)
        {
            if (i >= maxVisibleLights) break;

            VisibleLight light = cullingResults.visibleLights[i];
            visibleLightColors[i] = light.finalColor;
            Vector4 attenuation = Vector4.zero;
            attenuation.w = 1;
            if (light.lightType == LightType.Directional)
            {
                Vector4 v = light.localToWorld.GetColumn(2);
                v.x = -v.x;
                v.y = -v.y;
                v.z = -v.z;
                visibleLightDirectionsOrPositions[i] = v;
            } else
            {
                visibleLightDirectionsOrPositions[i] = light.localToWorld.GetColumn(3);
                attenuation.x = 1f / Mathf.Max(light.range * light.range, 0.00001f);

                if (light.lightType == LightType.Spot)
                {
                    Vector4 v = light.localToWorld.GetColumn(2);
                    v.x = -v.x;
                    v.y = -v.y;
                    v.z = -v.z;
                    visisbleLightSpotDirections[i] = v;
                    float outerRad = Mathf.Deg2Rad * 0.5f * light.spotAngle;
                    float outerCos = Mathf.Cos(outerRad);
                    float outerTan = Mathf.Tan(outerRad);
                    float innerCos = Mathf.Cos(Mathf.Atan((46f/64f) * outerTan));
                    float angleRange = Mathf.Max(innerCos - outerCos, 0.001f);
                    attenuation.z = 1f / angleRange;
                    attenuation.w = -outerCos * attenuation.z;
                }
            }
            visisbleLightAtenuations[i] = attenuation;
        }

        for (; i < maxVisibleLights; i++)
        {
            visibleLightColors[i] = Color.clear;
        }

        // 移除列表中不可见的灯光
        if (cullingResults.visibleLights.Count > maxVisibleLights)
        {
            int[] lightIndices = cullingResults.GetLightIndexMap();
            //NativeArray<int> lightIndices = cullingResults.GetLightIndexMap(Allocator.Temp);
            for (i = maxVisibleLights; i < cullingResults.visibleLights.Count; i++)
            {
                lightIndices[i] = -1;
            }
            cullingResults.SetLightIndexMap(lightIndices);
        }
    }

    void RenderShadows(ScriptableRenderContext context)
    {
        shadowMap = RenderTexture.GetTemporary(4096, 4096, 16, RenderTextureFormat.Shadowmap);
        shadowMap.filterMode = FilterMode.Bilinear;
        shadowMap.wrapMode = TextureWrapMode.Clamp;

        CoreUtils.SetRenderTarget(shadowBuffer, shadowMap, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, ClearFlag.Depth);
        shadowBuffer.BeginSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        Matrix4x4 viewMatrix, projectionMatrix;
        ShadowSplitData splitData;
        cullingResults.ComputeSpotShadowMatricesAndCullingPrimitives(0, out viewMatrix, out projectionMatrix, out splitData);
        shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
        context.ExecuteCommandBuffer(shadowBuffer);

        // draw shadow
        var shadowSettings = new DrawShadowsSettings(cullingResults, 0);
        context.DrawShadows(ref shadowSettings);
        
        if (SystemInfo.usesReversedZBuffer)
        {
            projectionMatrix.m20 = -projectionMatrix.m20;
            projectionMatrix.m21 = -projectionMatrix.m21;
            projectionMatrix.m22 = -projectionMatrix.m22;
            projectionMatrix.m23 = -projectionMatrix.m23;
        }
        // clip[-1,1] -> uv[0,1]
        var scaleOffset = Matrix4x4.identity;
        scaleOffset.m00 = scaleOffset.m11 = scaleOffset.m22 = 0.5f;
        scaleOffset.m03 = scaleOffset.m13 = scaleOffset.m23 = 0.5f;
        Matrix4x4 worldToShadowMatrix = scaleOffset * projectionMatrix * viewMatrix;
        shadowBuffer.SetGlobalMatrix(worldToShadowMatrixId, worldToShadowMatrix);
        shadowBuffer.SetGlobalTexture(shadowMapId, shadowMap);

        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        
    }
}