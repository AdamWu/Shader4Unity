using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class MaskEffect : MonoBehaviour
{
    public Vector2 pos = Vector2.one/2;
    [Range(0.1f, 1f)]
    public float radius = 0.2f;
    [Range(0.01f, 1f)]
    public float blurStrength = 0.2f;

    [HideInInspector]
    public Shader maskShader;

    Material maskMaterial;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (maskMaterial == null)
        {
            maskMaterial = new Material(maskShader);
            maskMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
        
        maskMaterial.SetVector("_Pos", pos);
        maskMaterial.SetFloat("_Radius", radius * Mathf.Min(Screen.width, Screen.height));
        maskMaterial.SetFloat("_BlurStrength", blurStrength);

        Graphics.Blit(source, destination, maskMaterial);
    }

    private void Update()
    {
        Vector2 mousePos = Input.mousePosition;
        pos = new Vector2(mousePos.x / Screen.width, mousePos.y / Screen.height);
    }
}
