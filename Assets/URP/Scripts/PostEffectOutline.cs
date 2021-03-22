using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PostEffectOutline : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Material material;
    }
    public Setting setting = new Setting();

    class CustomRenderPass : ScriptableRenderPass
    {
        private Material blitMaterial = null;
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetHandle destination { get; set; }
        public FilterMode filterMode { get; set; }
        private string m_ProfilerTag = "Sobel Outline";

        private RenderTargetHandle m_TemporaryColorTexture;

        public CustomRenderPass(RenderPassEvent evt, Material material)
        {
            renderPassEvent = evt;
            blitMaterial = material;
            m_TemporaryColorTexture.Init("_TemporaryColorTexture");
        }

        public void Setup(RenderTargetIdentifier source, RenderTargetHandle destination)
        {
            this.source = source;
            this.destination = destination;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;

            cmd.SetGlobalTexture("_MainTex", source);

            // Can't read and write to same color target, create a temp render target to blit. 
            if (destination == RenderTargetHandle.CameraTarget)
            {
                cmd.GetTemporaryRT(m_TemporaryColorTexture.id, opaqueDesc);
                Blit(cmd, source, m_TemporaryColorTexture.Identifier(), blitMaterial);
                Blit(cmd, m_TemporaryColorTexture.Identifier(), source);
            }
            else
            {
                //Blit(cmd, source, destination.Identifier(), blitMaterial);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (destination == RenderTargetHandle.CameraTarget)
                cmd.ReleaseTemporaryRT(m_TemporaryColorTexture.id);
        }
    }
    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(setting.Event, setting.material);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;

        m_ScriptablePass.Setup(src, RenderTargetHandle.CameraTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
