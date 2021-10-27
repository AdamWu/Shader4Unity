using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

[RequireComponent(typeof(Camera))]
public class CustomDepthTexture : MonoBehaviour
{
    private Camera camera;

    private RenderTexture depthRT;
    private RenderTexture colorRT;
    private RenderTexture depthTex;

    void Start()
    {
        camera = GetComponent<Camera>();

        int Width = camera.pixelWidth;
        int Height = camera.pixelHeight;

        depthRT = new RenderTexture(Width, Height, 24, RenderTextureFormat.Depth);
        depthRT.name = "Cunstom DepthBuffer";
        colorRT = new RenderTexture(Width, Height, 0, RenderTextureFormat.RGB111110Float);
        colorRT.name = "Cunstom ColorBuffer";

        depthTex = new RenderTexture(Width, Height, 0, RenderTextureFormat.R16);
        depthTex.name = "Cunstom DepthTexture";
        

        CommandBuffer cb = new CommandBuffer();
        cb.name = "CommandBuffer - CustumDepthTexture";
        cb.Blit(depthRT.depthBuffer, depthTex.colorBuffer);
        camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, cb);

        Shader.SetGlobalTexture("_LastDepthTexture", depthTex);

        RawImage rawImage = GameObject.Find("/Canvas/RawImage").GetComponent<RawImage>();
        rawImage.texture = colorRT;
    }
    
    void OnPreRender()
    {
        camera.SetTargetBuffers(colorRT.colorBuffer, depthRT.depthBuffer);
    }

    private void OnPostRender()
    {
        // colorbuffer to frame
        Graphics.Blit(colorRT, null as RenderTexture);
    }
}
