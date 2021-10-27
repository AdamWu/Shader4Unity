using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CommandBufferBlurRefraction : MonoBehaviour
{
    public Shader blurShader;
    
    private Dictionary<Camera, CommandBuffer> mCommandBuffers = new Dictionary<Camera, CommandBuffer>();
    private Material mMaterial;

    private void OnEnable()
    {
        
    }

    private void OnWillRenderObject()
    {
        if (!isActiveAndEnabled) return;

        Camera camera = Camera.current;
        if (!camera) return;

        if (mCommandBuffers.ContainsKey(camera)) return;

        if (mMaterial == null)
        {
            mMaterial = new Material(blurShader);
            mMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        CommandBuffer cb = new CommandBuffer();
        cb.name = "grab screen and blur";

        mCommandBuffers.Add(camera, cb);

        // fetch screen texture
        int screenCopyTexture = Shader.PropertyToID("_ScreenCopyTexture");
        cb.GetTemporaryRT(screenCopyTexture, -1, -1, 0, FilterMode.Bilinear);
        cb.Blit(BuiltinRenderTextureType.CurrentActive, screenCopyTexture);
        
        // blur texture
        int blurTexture1 = Shader.PropertyToID("_Temp1");
        int blurTexture2 = Shader.PropertyToID("_Temp2");
        cb.GetTemporaryRT(blurTexture1, -2, -2, 0, FilterMode.Bilinear);
        cb.GetTemporaryRT(blurTexture2, -2, -2, 0, FilterMode.Bilinear);
        cb.Blit(screenCopyTexture, blurTexture1);
        cb.ReleaseTemporaryRT(screenCopyTexture);
        cb.SetGlobalVector("offsets", new Vector4(2, 0, 0, 0));
        cb.Blit(blurTexture1, blurTexture2, mMaterial);
        cb.SetGlobalVector("offsets", new Vector4(0, 2, 0, 0));
        cb.Blit(blurTexture2, blurTexture1, mMaterial);
        
        // get final texture
        cb.SetGlobalTexture("_GrabBlurTexture", blurTexture1);
        camera.AddCommandBuffer(CameraEvent.AfterSkybox, cb);
    }
}
