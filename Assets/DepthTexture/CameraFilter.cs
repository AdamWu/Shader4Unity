using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public enum FilterType
{
    Scene=0,
    Depth,
    DepthCompressed,
    Normal,
}

[RequireComponent(typeof(Camera))]
public class CameraFilter : MonoBehaviour
{
    public Shader shader;
    public FilterType type = FilterType.Depth;

    private Camera camera;
    private CommandBuffer cb;

    private FilterType lasType;

    void Start()
    {
        camera = GetComponent<Camera>();

        cb = new CommandBuffer();
        cb.name = "CommandBuffer blit";
        camera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, cb);

        UpdateCameraFilter();
    }

    private void Update()
    {
        if (type != lasType)
        {
            lasType = type;
            UpdateCameraFilter();
        }
    }

    void UpdateCameraFilter()
    {
        if (camera == null) return;

        switch(type)
        {
            case FilterType.Scene:
                camera.renderingPath = RenderingPath.UsePlayerSettings;
                camera.clearFlags = CameraClearFlags.Skybox;
                camera.SetReplacementShader(null, null);
                break;
            case FilterType.Depth:
            case FilterType.DepthCompressed:
            case FilterType.Normal:
                UpdateFilterType((int)type);
                break;
        }
    }

    void UpdateFilterType(int type)
    {
        camera.renderingPath = RenderingPath.Forward;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = Color.white;
        cb.SetGlobalInt("_FilterType", type);
        camera.SetReplacementShader(shader, "");
    }
    
}
