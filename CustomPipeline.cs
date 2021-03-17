using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;

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
    CommandBuffer shadowBuffer = new CommandBuffer { name = "Render Shadows" };

    CullingResults cullingResults;

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

    public CustomPipeline(bool enableDynamicBatching, bool enableInstancing)
    {
        GraphicsSettings.lightsUseLinearIntensity = true;

        this.enableDynamicBatching = enableDynamicBatching;
        this.enableInstancing = enableInstancing;
    }

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
        cullingResults = context.Cull(ref cullingParameters);
        context.SetupCameraProperties(camera);

        // clear
        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.BeginSample("Render Camera");
        cameraBuffer.ClearRenderTarget((clearFlags & CameraClearFlags.Depth) != 0, (clearFlags & CameraClearFlags.Color) != 0, camera.backgroundColor);

        // shadow
        RenderShadows(context);

        // light constans
        ConfigureLights();
        cameraBuffer.SetGlobalVectorArray(visibleLightColorsId, visibleLightColors);
        cameraBuffer.SetGlobalVectorArray(visibleLightDirectionsOrPositionsId, visibleLightDirectionsOrPositions);
        cameraBuffer.SetGlobalVectorArray(visibleLightAttenuationsId, visisbleLightAtenuations);
        cameraBuffer.SetGlobalVectorArray(visibleLightSpotDirectionsId, visisbleLightSpotDirections);

        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        // draw oqaque mesh
        var sortingSettings = new SortingSettings(camera);
        var drawSettings = new DrawingSettings(unlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = enableDynamicBatching,
            enableInstancing = enableInstancing,
            perObjectData = PerObjectData.LightProbe |
                PerObjectData.ReflectionProbes |
                PerObjectData.Lightmaps | PerObjectData.ShadowMask |
                PerObjectData.LightProbeProxyVolume |
                PerObjectData.OcclusionProbe |
                PerObjectData.LightData | PerObjectData.LightIndices,
        };
        
        for (int i = 0; i < legacyShaderTagIds.Length; i ++)
        {
            drawSettings.SetShaderPassName(i+1, legacyShaderTagIds[i]);
        }
        var filterSettings = new FilteringSettings(RenderQueueRange.opaque);
        context.DrawRenderers(cullingResults, ref drawSettings, ref filterSettings);

        // draw skybox
        context.DrawSkybox(camera);

        // draw transparent mesh
        filterSettings = new FilteringSettings(RenderQueueRange.transparent);
        context.DrawRenderers(cullingResults, ref drawSettings, ref filterSettings);
        
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
        for (; i < cullingResults.visibleLights.Length; i ++)
        {
            if (i >= maxVisibleLights) break;

            VisibleLight light = cullingResults.visibleLights[i];
            visibleLightColors[i] = light.finalColor;
            Vector4 attenuation = Vector4.zero;
            attenuation.w = 1;
            if (light.lightType == LightType.Directional)
            {
                Vector4 v = light.localToWorldMatrix.GetColumn(2);
                v.x = -v.x;
                v.y = -v.y;
                v.z = -v.z;
                visibleLightDirectionsOrPositions[i] = v;
            } else
            {
                visibleLightDirectionsOrPositions[i] = light.localToWorldMatrix.GetColumn(3);
                attenuation.x = 1f / Mathf.Max(light.range * light.range, 0.00001f);

                if (light.lightType == LightType.Spot)
                {
                    Vector4 v = light.localToWorldMatrix.GetColumn(2);
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
        if (cullingResults.visibleLights.Length > maxVisibleLights)
        {
            NativeArray<int> lightIndices = cullingResults.GetLightIndexMap(Allocator.Temp);
            for (i = maxVisibleLights; i < cullingResults.visibleLights.Length; i++)
            {
                lightIndices[i] = -1;
            }
            cullingResults.SetLightIndexMap(lightIndices);
        }
    }

    void RenderShadows(ScriptableRenderContext context)
    {
        shadowBuffer.GetTemporaryRT(shadowMapId, 512, 512, 16, FilterMode.Bilinear, RenderTextureFormat.Depth);
        shadowMap = RenderTexture.GetTemporary(512, 512, 16, RenderTextureFormat.Shadowmap);
        shadowMap.filterMode = FilterMode.Bilinear;
        shadowMap.wrapMode = TextureWrapMode.Clamp;

        CoreUtils.SetRenderTarget(shadowBuffer, shadowMap, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, ClearFlag.Depth);
        shadowBuffer.BeginSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        Matrix4x4 viewMatrix, projectMatrix;
        ShadowSplitData splitData;
        cullingResults.ComputeSpotShadowMatricesAndCullingPrimitives(0, out viewMatrix, out projectMatrix, out splitData);
        shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectMatrix);
        context.ExecuteCommandBuffer(shadowBuffer);

        // draw shadow
        var shadowSettings = new ShadowDrawingSettings(cullingResults, 0);
        context.DrawShadows(ref shadowSettings);

        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        
    }
}