using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(Camera))]
public class PostProcessDepthTexture : MonoBehaviour
{
    public Shader shader;

    private Camera camera;
    private Material material;

    // Start is called before the first frame update
    void Start()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.Depth;
        //camera.depthTextureMode = DepthTextureMode.DepthNormals;
    }
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (material == null)
        {
            material = new Material(shader);
            material.hideFlags = HideFlags.HideAndDontSave;
        }

        Graphics.Blit(source, destination, material);
    }

}
