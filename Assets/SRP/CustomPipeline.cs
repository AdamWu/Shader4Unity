using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.GlobalIllumination;
using LightType = UnityEngine.LightType;
using Conditional = System.Diagnostics.ConditionalAttribute;

public class CustomPipeline : RenderPipeline
{
#if UNITY_EDITOR
    static Lightmapping.RequestLightsDelegate lightmappingLightsDelegate = (Light[] inputLights, NativeArray<LightDataGI> outputLights) => {
        LightDataGI lightData = new LightDataGI();
        for (int i = 0; i < inputLights.Length; i ++)
        {
            Light light = inputLights[i];
            switch (light.type)
            {
                case LightType.Directional:
                    var directionalLight = new DirectionalLight();
                    LightmapperUtils.Extract(light, ref directionalLight);
                    lightData.Init(ref directionalLight);
                    break;
                case LightType.Point:
                    var pointLight = new PointLight();
                    LightmapperUtils.Extract(light, ref pointLight);
                    lightData.Init(ref pointLight);
                    break;
                case LightType.Spot:
                    var spotLight = new SpotLight();
                    LightmapperUtils.Extract(light, ref spotLight);
                    lightData.Init(ref spotLight);
                    break;
                case LightType.Area:
                    var rectangleLight = new RectangleLight();
                    LightmapperUtils.Extract(light, ref rectangleLight);
                    lightData.Init(ref rectangleLight);
                    break;
                default:
                    lightData.InitNoBake(light.GetInstanceID());
                    break;
            }
            lightData.falloff = FalloffType.InverseSquared;
            outputLights[i] = lightData;
        }
    };
#endif

    // light
    const int maxVisibleLights = 16;
    static int visibleLightColorsId = Shader.PropertyToID("_VisibleLightColors");
    static int visibleLightDirectionsOrPositionsId = Shader.PropertyToID("_VisibleLightDirectionsOrPositions");
    static int visibleLightAttenuationsId = Shader.PropertyToID("_VisibleLightAttenuations");
    static int visibleLightSpotDirectionsId = Shader.PropertyToID("_VisibleLightSpotDirections");
    static int lightIndicesOffsetAndCountID = Shader.PropertyToID("unity_LightIndicesOffsetAndCount");

    // shadowmap
    const string shadowsHardKeyword = "_SHADOWS_HARD";
    const string shadowsSoftKeyword = "_SHADOWS_SOFT";
    const string cascadedShadowsHardKeyword = "_CASCADED_SHADOWS_HARD";
    const string cascadedShadowsSoftKeyword = "_CASCADED_SHADOWS_SOFT";
    const string shadowmaskKeyword = "_SHADOWMASK";
    const string distanceShadowmaskKeyword = "_DISTANCE_SHADOWMASK";
    static int shadowMapId = Shader.PropertyToID("_ShadowMap");
    static int worldToShadowMatricesId = Shader.PropertyToID("_WorldToShadowMatrices");
    static int shadowBiasId = Shader.PropertyToID("_ShadowBias");
    static int shadowDataId = Shader.PropertyToID("_ShadowData");
    static int shadowMapSizeId = Shader.PropertyToID("_ShadowMapSize");
    static int globalShadowDataId = Shader.PropertyToID("_GlobalShadowData");
    static int cascadedShadowMapId = Shader.PropertyToID("_CascadedShadowMap");
    static int worldToShadowCascadeMatricesId = Shader.PropertyToID("_WorldToShadowCascadeMatrices");
    static int cascadedShadowMapSizeId = Shader.PropertyToID("_CascadedShadowMapSize");
    static int cascadedShadowStrengthId = Shader.PropertyToID("_CascadedShadowStrength");
    static int cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    // shadow mask
    static int visibleLightOcclusionMasksId = Shader.PropertyToID("_VisibleLightOcclusionMasks");

    // post processing
    static int cameraColorTextureId = Shader.PropertyToID("_CameraColorTexture");
    static int cameraDepthTextureId = Shader.PropertyToID("_CameraDepthTexture");

    CommandBuffer cameraBuffer = new CommandBuffer { name = "Render Camera" };
    CommandBuffer shadowBuffer = new CommandBuffer { name = "Render Shadows" };
    CommandBuffer postProcessingBuffer = new CommandBuffer { name = "Post Processing" };
    //DrawRendererFlags drawFlags;
    CullingResults cull;

    // lights
    Vector4[] visibleLightColors = new Vector4[maxVisibleLights];
    Vector4[] visibleLightDirectionsOrPositions = new Vector4[maxVisibleLights];
    Vector4[] visibleLightAttenuations = new Vector4[maxVisibleLights];
    Vector4[] visibleLightSpotDirections = new Vector4[maxVisibleLights];
    
    // shadow
    RenderTexture shadowMap, cascadedShadowMap;
    Vector4[] shadowData = new Vector4[maxVisibleLights];
    Matrix4x4[] worldToShadowMatrices = new Matrix4x4[maxVisibleLights];
    int shadowMapSize;
    int shadowTileCount;
    float shadowDistance, shadowFadeRange;
    int shadowCascades;
    Vector3 shadowCascadeSplit;
    bool mainLightExists;
    Matrix4x4[] worldToShadowCascadeMatrices = new Matrix4x4[5];
    Vector4[] cascadeCullingSpheres = new Vector4[4];
    Vector4 globalShadowData;
    Vector4[] visibleLightOcclusionMasks = new Vector4[maxVisibleLights];
    Vector4[] occlusionMasks =
    {
        new Vector4(-1f, 0, 0, 0),
        new Vector4(1f, 0, 0, 0),
        new Vector4(0, 1f, 0, 0),
        new Vector4(0, 0, 1f, 0),
        new Vector4(0, 0, 0, 1f),
    };

    Material errorMaterial;

    CustomPostProcessingStack defaultStack;
    float renderScale = 1;
    int msaaSamples = 1;
    bool allowHDR;

    CameraRenderer renderer = new CameraRenderer();
    bool useDynamicBatching, useGPUInstancing;
    ShadowSettings shadowSettings;

    public CustomPipeline(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher, ShadowSettings shadowSettings,
        CustomPostProcessingStack defaultStack, 
        int shadowMapSize, float shadowDistance, float shadowFadeRange, int shadowCascades, Vector3 shadowCascadeSplit,
        float renderScale, int msaaSamples, bool allowHDR)
    {
        GraphicsSettings.lightsUseLinearIntensity = true;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;

        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.shadowSettings = shadowSettings;


        this.defaultStack = defaultStack;
        this.shadowMapSize = shadowMapSize;
        this.shadowDistance = shadowDistance;
        this.shadowFadeRange = shadowFadeRange;
        this.shadowCascades = shadowCascades;
        this.shadowCascadeSplit = shadowCascadeSplit;

        this.renderScale = renderScale;
        QualitySettings.antiAliasing = msaaSamples;
        this.msaaSamples = Mathf.Max(QualitySettings.antiAliasing, 1);

        this.allowHDR = allowHDR;

        globalShadowData.y = 1f / shadowFadeRange;

        if (SystemInfo.usesReversedZBuffer)
        {
            worldToShadowCascadeMatrices[4].m33 = 1f;
        }

#if UNITY_EDITOR
        Lightmapping.SetDelegate(lightmappingLightsDelegate);
#endif
    }

    /*
    public override void Dispose()
    {
        base.Dispose();
#if UNITY_EDITOR
        Lightmapping.ResetDelegate();
#endif
    }
    */

    protected override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        foreach (var camera in cameras)
        {
            renderer.Render(renderContext, camera, useDynamicBatching, useGPUInstancing, shadowSettings);
        }
    }

    void Render(ScriptableRenderContext context, Camera camera)
    {
        ScriptableCullingParameters cullingParameters;
        if (!camera.TryGetCullingParameters(out cullingParameters))
        {
            return;
        }

        // shadow distance
        cullingParameters.shadowDistance = Mathf.Min(shadowDistance, camera.farClipPlane);

        cull = context.Cull(ref cullingParameters);
        if (cull.visibleLights.Length > 0)
        {
            ConfigureLights();
            if (mainLightExists)
            {
                RenderCascadedShadows(context);
            } else
            {
                cameraBuffer.DisableShaderKeyword(cascadedShadowsHardKeyword);
                cameraBuffer.DisableShaderKeyword(cascadedShadowsSoftKeyword);
            }
            if (shadowTileCount > 0)
            {
                RenderShadows(context);
            }
        }
        else
        {
            cameraBuffer.SetGlobalVector(lightIndicesOffsetAndCountID, Vector4.zero);
            cameraBuffer.DisableShaderKeyword(cascadedShadowsHardKeyword);
            cameraBuffer.DisableShaderKeyword(cascadedShadowsSoftKeyword);
        }

        // camera setup
        context.SetupCameraProperties(camera);

        // post-processing
        var customPipelineCamera = camera.GetComponent<CustomPipelineCamera>();
        CustomPostProcessingStack activeStack = customPipelineCamera ? customPipelineCamera.PostProcessingStack : defaultStack;
        bool scaledRendering = renderScale != 1f && camera.cameraType == CameraType.Game;
        int renderWidth = camera.pixelWidth;
        int renderHeight = camera.pixelHeight;
        if (scaledRendering)
        {
            renderWidth = (int)(renderWidth * renderScale);
            renderHeight = (int)(renderHeight * renderScale);
        }
        int renderSamples = camera.allowMSAA ? msaaSamples : 1;
        bool renderToTexture = scaledRendering || renderSamples > 1 || activeStack;
        bool needsDepth = activeStack && activeStack.NeedsDepth;
        bool needsDirectDepth = needsDepth && renderSamples == 1; // post && no msaa
        bool needsDepthOnlyPass = needsDepth && renderSamples > 1; // post && msaa
        RenderTextureFormat format = allowHDR && camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
        if (renderToTexture)
        {
            cameraBuffer.GetTemporaryRT(cameraColorTextureId, renderWidth, renderHeight, needsDirectDepth?0:24, FilterMode.Bilinear,
                format, RenderTextureReadWrite.Default, renderSamples);
            if (needsDepth)
            {
                cameraBuffer.GetTemporaryRT(cameraDepthTextureId, renderWidth, renderHeight, 24, FilterMode.Point,
                    RenderTextureFormat.Depth, RenderTextureReadWrite.Linear, 1);
            }
            if (needsDirectDepth)
            {
                cameraBuffer.SetRenderTarget(
                    cameraColorTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                    cameraDepthTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }
            else
            {
                cameraBuffer.SetRenderTarget(
                    cameraColorTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }
        }

        // clear
        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.ClearRenderTarget((clearFlags & CameraClearFlags.Depth) != 0, (clearFlags & CameraClearFlags.Color) != 0, camera.backgroundColor);

        // global constants
        cameraBuffer.BeginSample("Render Camera");
        cameraBuffer.SetGlobalVectorArray(visibleLightColorsId, visibleLightColors);
        cameraBuffer.SetGlobalVectorArray(visibleLightDirectionsOrPositionsId, visibleLightDirectionsOrPositions);
        cameraBuffer.SetGlobalVectorArray(visibleLightAttenuationsId, visibleLightAttenuations);
        cameraBuffer.SetGlobalVectorArray(visibleLightSpotDirectionsId, visibleLightSpotDirections);
        cameraBuffer.SetGlobalVectorArray(visibleLightOcclusionMasksId, visibleLightOcclusionMasks);
        globalShadowData.z = 1f - cullingParameters.shadowDistance * globalShadowData.y;
        cameraBuffer.SetGlobalVector(globalShadowDataId, globalShadowData);
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        // render mesh opaque
        var sortingSettings = new SortingSettings(camera);
        sortingSettings.criteria = SortingCriteria.CommonOpaque;
        var drawSettings = new DrawingSettings(new ShaderTagId("SRPDefaultUnlit"), sortingSettings);
        drawSettings.enableDynamicBatching = true;
        drawSettings.enableInstancing = true;
        if (cull.visibleLights.Length > 0)
        {
            drawSettings.perObjectData = PerObjectData.LightIndices;
        }
        drawSettings.perObjectData |= PerObjectData.ReflectionProbes;
        drawSettings.perObjectData |= PerObjectData.Lightmaps;
        drawSettings.perObjectData |= PerObjectData.LightProbe;
        drawSettings.perObjectData |= PerObjectData.LightProbeProxyVolume;
        drawSettings.perObjectData |= PerObjectData.ShadowMask; // shadow for static
        drawSettings.perObjectData |= PerObjectData.OcclusionProbe; // shadow for dynamic
        drawSettings.perObjectData |= PerObjectData.OcclusionProbeProxyVolume; // shadow for dynamic
        var filterSettings = new FilteringSettings(RenderQueueRange.opaque);
        filterSettings.renderQueueRange = RenderQueueRange.opaque;
        context.DrawRenderers(cull, ref drawSettings, ref filterSettings);

        // render skybox
        context.DrawSkybox(camera);

        // post-processing
        if (activeStack)
        {
            if (needsDepthOnlyPass)
            {
                var depthOnlyDrawSettings = new DrawingSettings(new ShaderTagId("DepthOnly"), sortingSettings);
                cameraBuffer.SetRenderTarget(cameraDepthTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cameraBuffer.ClearRenderTarget(true, false, Color.clear);
                context.ExecuteCommandBuffer(cameraBuffer);
                cameraBuffer.Clear();
                context.DrawRenderers(cull, ref drawSettings, ref filterSettings);
            }
            activeStack.RenderAfterOpaque(postProcessingBuffer, cameraColorTextureId, cameraDepthTextureId, renderWidth, renderHeight, msaaSamples, format);
            context.ExecuteCommandBuffer(postProcessingBuffer);
            postProcessingBuffer.Clear();

            if (needsDirectDepth)
            {
                cameraBuffer.SetRenderTarget(
                    cameraColorTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                    cameraDepthTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            } else
            {
                cameraBuffer.SetRenderTarget(
                    cameraColorTextureId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }
            context.ExecuteCommandBuffer(cameraBuffer);
            cameraBuffer.Clear();
        }

        // render mesh transparent
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        filterSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cull, ref drawSettings, ref filterSettings);

        //DrawDefaultPipeline(context, camera);

        // post-processing
        if (renderToTexture)
        {
            if (activeStack)
            {
                activeStack.RenderAfterTransparent(postProcessingBuffer, cameraColorTextureId, cameraDepthTextureId, renderWidth, renderHeight, msaaSamples, format);
                context.ExecuteCommandBuffer(postProcessingBuffer);
                postProcessingBuffer.Clear();
            }
            else
            {
                cameraBuffer.Blit(cameraColorTextureId, BuiltinRenderTextureType.CameraTarget);
            }
            cameraBuffer.ReleaseTemporaryRT(cameraColorTextureId);
            if (needsDepth)
            {
                cameraBuffer.ReleaseTemporaryRT(cameraDepthTextureId);
            }
        }

        cameraBuffer.EndSample("Render Camera");
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();
    
        // sumbit
        context.Submit();

        // release
        if (shadowMap)
        {
            RenderTexture.ReleaseTemporary(shadowMap);
            shadowMap = null;
        }
        if (cascadedShadowMap)
        {
            RenderTexture.ReleaseTemporary(cascadedShadowMap);
            cascadedShadowMap = null;
        }
    }

    void ConfigureLights()
    {
        mainLightExists = false;
        shadowTileCount = 0;
        bool shadowmaskExists = false;
        for (int i = 0; i < cull.visibleLights.Length; i++)
        {
            if (i == maxVisibleLights) break;
            
            VisibleLight light = cull.visibleLights[i];
            visibleLightColors[i] = light.finalColor;
            Vector4 attenuation = Vector4.zero;
            attenuation.w = 1f;
            Vector4 shadow = Vector4.zero;

            // shadowmask ?
            LightBakingOutput baking = light.light.bakingOutput;
            visibleLightOcclusionMasks[i] = occlusionMasks[baking.occlusionMaskChannel + 1];
            if (baking.lightmapBakeType == LightmapBakeType.Mixed)
            {
                shadowmaskExists |= baking.mixedLightingMode == MixedLightingMode.Shadowmask;
            }

            if (light.lightType == LightType.Directional)
            {
                Vector4 v = light.localToWorldMatrix.GetColumn(2);
                v.x = -v.x;
                v.y = -v.y;
                v.z = -v.z;
                visibleLightDirectionsOrPositions[i] = v;
                shadow = ConfigureShadows(i, light.light);
                shadow.z = 1f;// flag
                if (i == 0 && shadow.x > 0f && shadowCascades > 0)
                {
                    mainLightExists = true;
                    shadowTileCount -= 1;
                }
            }
            else
            {
                visibleLightDirectionsOrPositions[i] = light.localToWorldMatrix.GetColumn(3);
                attenuation.x = 1f / Mathf.Max(light.range * light.range, 0.00001f);
                if (light.lightType == LightType.Spot)
                {
                    Vector4 v = light.localToWorldMatrix.GetColumn(2);
                    v.x = -v.x;
                    v.y = -v.y;
                    v.z = -v.z;
                    visibleLightSpotDirections[i] = v;

                    float outerRad = Mathf.Deg2Rad * 0.5f * light.spotAngle;
                    float outerCos = Mathf.Cos(outerRad);
                    float outerTan = Mathf.Tan(outerRad);
                    float innerCos = Mathf.Cos(Mathf.Atan((46f / 64f) * outerTan));
                    float angleRange = Mathf.Max(innerCos - outerCos, 0.001f);
                    attenuation.z = 1f / angleRange;
                    attenuation.w = -outerCos * attenuation.z;
                    shadow = ConfigureShadows(i, light.light);
                } else
                {
                    visibleLightSpotDirections[i] = Vector4.one;
                }
            }

            visibleLightAttenuations[i] = attenuation;
            shadowData[i] = shadow;
        }

        // shadowmask
        bool useDistanceShadowmask = QualitySettings.shadowmaskMode == ShadowmaskMode.DistanceShadowmask;
        CoreUtils.SetKeyword(cameraBuffer, shadowmaskKeyword, shadowmaskExists && !useDistanceShadowmask);
        CoreUtils.SetKeyword(cameraBuffer, distanceShadowmaskKeyword, shadowmaskExists && useDistanceShadowmask);

        if (mainLightExists || cull.visibleLights.Length > maxVisibleLights)
        {
            NativeArray<int> lightIndices = cull.GetLightIndexMap(Allocator.Temp);
            if (mainLightExists)
            {
                lightIndices[0] = -1;
            }
            for (int i = maxVisibleLights; i < cull.visibleLights.Length; i++)
            {
                lightIndices[i] = -1;
            }
            cull.SetLightIndexMap(lightIndices);
        }
    }

    Vector4 ConfigureShadows(int lightIndex, Light shadowLight)
    {
        Vector4 shadow = Vector4.zero;
        Bounds shadowBounds;
        if (shadowLight.shadows != LightShadows.None && cull.GetShadowCasterBounds(lightIndex, out shadowBounds))
        {
            shadowTileCount += 1;
            shadow.x = shadowLight.shadowStrength;
            shadow.y = shadowLight.shadows == LightShadows.Soft ? 1f : 0f;
        }
        return shadow;
    }
    
    RenderTexture SetShadowRenderTarget()
    {
        RenderTexture texture = RenderTexture.GetTemporary(shadowMapSize, shadowMapSize, 16, RenderTextureFormat.Shadowmap);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Clamp;
        CoreUtils.SetRenderTarget(shadowBuffer, texture, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, ClearFlag.Depth);
        return texture;
    }

    Vector2 ConfigureShadowTile(int tileIndex, int split, float tileSize)
    {
        Vector2 tileOffset;
        tileOffset.x = tileIndex % split;
        tileOffset.y = tileIndex / split;
        Rect tileViewport = new Rect(tileOffset.x * tileSize, tileOffset.y * tileSize, tileSize, tileSize);

        // ²Ã¼ô
        shadowBuffer.SetViewport(tileViewport);
        shadowBuffer.EnableScissorRect(new Rect(tileViewport.x + 4f, tileViewport.y + 4f, tileSize - 8f, tileSize - 8f));
        return tileOffset;
    }

    void CalculateWorldToShadowMatrix(ref Matrix4x4 viewMatrix, ref Matrix4x4 projectionMatrix, out Matrix4x4 worldToShadowMatrix)
    {
        if (SystemInfo.usesReversedZBuffer)
        {
            projectionMatrix.m20 = -projectionMatrix.m20;
            projectionMatrix.m21 = -projectionMatrix.m21;
            projectionMatrix.m22 = -projectionMatrix.m22;
            projectionMatrix.m23 = -projectionMatrix.m23;
        }
        var scaleOffset = Matrix4x4.identity;
        scaleOffset.m00 = scaleOffset.m11 = scaleOffset.m22 = 0.5f;
        scaleOffset.m03 = scaleOffset.m13 = scaleOffset.m23 = 0.5f;
        worldToShadowMatrix = scaleOffset * (projectionMatrix * viewMatrix);
    }

    void RenderShadows(ScriptableRenderContext context)
    {
        int split;
        if (shadowTileCount <= 1)
        {
            split = 1;
        }
        else if (shadowTileCount <= 4)
        {
            split = 2;
        }
        else if (shadowTileCount <= 9)
        {
            split = 3;
        }
        else
        {
            split = 4;
        }

        float tileSize = shadowMapSize / split;
        float tileScale = 1f / split;
        Rect tileViewport = new Rect(0f, 0f, tileSize, tileSize);

        // shadowmap
        shadowMap = SetShadowRenderTarget();

        shadowBuffer.BeginSample("Render Shadows");
        globalShadowData.x = tileScale;
        //shadowBuffer.SetGlobalVector(globalShadowDataId, new Vector4(tileScale, shadowDistance*shadowDistance));
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        int tileIndex = 0;
        for (int i = mainLightExists?1:0; i < cull.visibleLights.Length; i++)
        {
            if (i == maxVisibleLights) break;
            if (shadowData[i].x <= 0f) continue;

            VisibleLight visibleLight = cull.visibleLights[i];

            Matrix4x4 viewMatrix, projectionMatrix;
            ShadowSplitData splitData;
            bool validShadows;
            if (shadowData[i].z > 0f)
            {
                // directional
                validShadows = cull.ComputeDirectionalShadowMatricesAndCullingPrimitives(i, 0, 1, Vector3.right, (int)tileSize, visibleLight.light.shadowNearPlane,
                    out viewMatrix, out projectionMatrix, out splitData);
            } else
            {
                validShadows = cull.ComputeSpotShadowMatricesAndCullingPrimitives(i, out viewMatrix, out projectionMatrix, out splitData);
            }
            if (!validShadows)
            {
                shadowData[i].x = 0f;
                continue;
            }

            Vector2 tileOffset = ConfigureShadowTile(tileIndex, split, tileSize);
            
            shadowData[i].z = tileOffset.x * tileScale;
            shadowData[i].w = tileOffset.y * tileScale;
            
            shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            shadowBuffer.SetGlobalFloat(shadowBiasId, visibleLight.light.shadowBias);
            context.ExecuteCommandBuffer(shadowBuffer);
            shadowBuffer.Clear();

            // draw shadow for light i
            var shadowSettings = new ShadowDrawingSettings(cull, i);
            shadowSettings.splitData = splitData;
            context.DrawShadows(ref shadowSettings);
            
            // save matrix
            CalculateWorldToShadowMatrix(ref viewMatrix, ref projectionMatrix, out worldToShadowMatrices[i]);

            tileIndex += 1;
        }

        // ²Ã¼ô½áÊø
        shadowBuffer.DisableScissorRect();

        shadowBuffer.SetGlobalTexture(shadowMapId, shadowMap);
        shadowBuffer.SetGlobalMatrixArray(worldToShadowMatricesId, worldToShadowMatrices);
        shadowBuffer.SetGlobalVectorArray(shadowDataId, shadowData);
        float invShadowMapSize = 1f / shadowMapSize;
        shadowBuffer.SetGlobalVector(shadowMapSizeId, new Vector4(invShadowMapSize, invShadowMapSize, shadowMapSize, shadowMapSize));
        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();
    }

    void RenderCascadedShadows(ScriptableRenderContext context)
    {
        float tileSize = shadowMapSize / 2;
        // shadowmap
        cascadedShadowMap = SetShadowRenderTarget();

        shadowBuffer.BeginSample("Render Shadows");
        //shadowBuffer.SetGlobalVector(globalShadowDataId, new Vector4(0, shadowDistance * shadowDistance));
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        Light shadowLight = cull.visibleLights[0].light;
        shadowBuffer.SetGlobalFloat(shadowBiasId, shadowLight.shadowBias);

        var shadowSettings = new ShadowDrawingSettings(cull, 0);
        var tileMatrix = Matrix4x4.identity;
        tileMatrix.m00 = tileMatrix.m11 = 0.5f;

        for (int i = 0; i < shadowCascades; i ++)
        {
            Matrix4x4 viewMatrix, projectionMatrix;
            ShadowSplitData splitData;
            cull.ComputeDirectionalShadowMatricesAndCullingPrimitives(0, i, shadowCascades, shadowCascadeSplit, (int)tileSize, shadowLight.shadowNearPlane,
                out viewMatrix, out projectionMatrix, out splitData);

            Vector2 tileOffset = ConfigureShadowTile(i, 2, tileSize);
            shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            context.ExecuteCommandBuffer(shadowBuffer);
            shadowBuffer.Clear();

            // draw shadow for light i
            shadowSettings.splitData = splitData;
            cascadeCullingSpheres[i] = splitData.cullingSphere;
            cascadeCullingSpheres[i].w *= cascadeCullingSpheres[i].w * 1.0f;
            context.DrawShadows(ref shadowSettings);
            
            // save matrix
            CalculateWorldToShadowMatrix(ref viewMatrix, ref projectionMatrix, out worldToShadowCascadeMatrices[i]);

            tileMatrix.m03 = tileOffset.x * 0.5f;
            tileMatrix.m13 = tileOffset.y * 0.5f;
            worldToShadowCascadeMatrices[i] = tileMatrix * worldToShadowCascadeMatrices[i];
        }

        // ²Ã¼ô½áÊø
        shadowBuffer.DisableScissorRect();
        shadowBuffer.SetGlobalTexture(cascadedShadowMapId, cascadedShadowMap);
        shadowBuffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        shadowBuffer.SetGlobalMatrixArray(worldToShadowCascadeMatricesId, worldToShadowCascadeMatrices);
        float invShadowMapSize = 1f / shadowMapSize;
        shadowBuffer.SetGlobalVector(cascadedShadowMapSizeId, new Vector4(invShadowMapSize, invShadowMapSize, shadowMapSize, shadowMapSize));
        shadowBuffer.SetGlobalFloat(cascadedShadowStrengthId, shadowLight.shadowStrength);
        
        CoreUtils.SetKeyword(shadowBuffer, cascadedShadowsHardKeyword, shadowLight.shadows == LightShadows.Hard);
        CoreUtils.SetKeyword(shadowBuffer, cascadedShadowsSoftKeyword, shadowLight.shadows != LightShadows.Hard);

        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();
    }

    [Conditional("DEVELOPMENT_BUILD"), Conditional("UNITY_EDITOR")]
    void DrawDefaultPipeline(ScriptableRenderContext context, Camera camera)
    {
        if (errorMaterial == null)
        {
            Shader errorShader = Shader.Find("Hidden/InternalErrorShader");
            errorMaterial = new Material(errorShader)
            {
                hideFlags = HideFlags.HideAndDontSave
            };
        }

        var drawSettings = new DrawingSettings(new ShaderTagId("SRPDefaultUnlit"), new SortingSettings(camera));
        drawSettings.SetShaderPassName(1, new ShaderTagId("Always"));
        drawSettings.SetShaderPassName(2, new ShaderTagId("ForwardBase"));
        drawSettings.SetShaderPassName(3, new ShaderTagId("PrepassBase"));
        drawSettings.SetShaderPassName(4, new ShaderTagId("Vertex"));
        drawSettings.SetShaderPassName(5, new ShaderTagId("VertexLMRGBM"));
        drawSettings.SetShaderPassName(6, new ShaderTagId("VertexLM"));
        //drawSettings.overrideMaterial = errorMaterial;

        var filterSettings = FilteringSettings.defaultValue;
        context.DrawRenderers(cull, ref drawSettings, ref filterSettings);
    }
}