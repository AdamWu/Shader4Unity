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
    Segmentation,
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
        
        var renderers = FindObjectsOfType<Renderer>();
        var mpb = new MaterialPropertyBlock();
        foreach (var r in renderers)
        {
            var id = r.gameObject.GetInstanceID();
            var layer = r.gameObject.layer;

            mpb.SetColor("_ObjectColor", EncodeIDAsColor(id));
            mpb.SetColor("_CategoryColor", EncodeLayerAsColor(layer));
            r.SetPropertyBlock(mpb);
        }

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
            case FilterType.Segmentation:
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


    public int SparsifyBits(byte value, int sparse)
    {
        int retVal = 0;
        for (int bits = 0; bits < 8; bits++, value >>= 1)
        {
            retVal |= (value & 1);
            retVal <<= sparse;
        }
        return retVal >> sparse;
    }
    public Color EncodeIDAsColor(int instanceId)
    {
        var uid = instanceId * 2;
        if (uid < 0)
            uid = -uid + 1;

        var sid =
            (SparsifyBits((byte)(uid >> 16), 3) << 2) |
            (SparsifyBits((byte)(uid >> 8), 3) << 1) |
             SparsifyBits((byte)(uid), 3);
        //Debug.Log(uid + " >>> " + System.Convert.ToString(sid, 2).PadLeft(24, '0'));

        var r = (byte)(sid >> 8);
        var g = (byte)(sid >> 16);
        var b = (byte)(sid);

        //Debug.Log(r + " " + g + " " + b);
        return new Color32(r, g, b, 255);
    }
    public static Color EncodeLayerAsColor(int layer)
    {
        // Following value must be in the range (0.5 .. 1.0)
        // in order to avoid color overlaps when using 'divider' in this func
        var z = .7f;
        
        // Lets create palette of unique 16 colors
        var uniqueColors = new Color[] {
            new Color(1,1,1,1), new Color(z,z,z,1),						// 0
			new Color(1,1,z,1), new Color(1,z,1,1), new Color(z,1,1,1), //
			new Color(1,z,0,1), new Color(z,0,1,1), new Color(0,1,z,1), // 7

			new Color(1,0,0,1), new Color(0,1,0,1), new Color(0,0,1,1), // 8
			new Color(1,1,0,1), new Color(1,0,1,1), new Color(0,1,1,1), //
			new Color(1,z,z,1), new Color(z,1,z,1)						// 15
		};

        // Create as many colors as necessary by using base 16 color palette
        // To create more than 16 - will simply adjust brightness with 'divider'
        var color = uniqueColors[layer % uniqueColors.Length];
        var divider = 1.0f + Mathf.Floor(layer / uniqueColors.Length);
        color /= divider;

        return color;
    }
}
