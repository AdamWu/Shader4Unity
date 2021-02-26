using UnityEngine;

[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader deferredFog;
    
    Material fogMaterial;

    Camera deferredCamera; 
    Vector3[] frustumCorners;
    Vector4[] vectorArray;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            fogMaterial = new Material(deferredFog); 
        }

        if (deferredCamera == null) 
        {
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
        }

        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f),
            deferredCamera.farClipPlane,
            deferredCamera.stereoActiveEye,
            frustumCorners
        );
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[1];
        vectorArray[2] = frustumCorners[2];
        vectorArray[3] = frustumCorners[3];
        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);

        Graphics.Blit(source, destination, fogMaterial);
    }
}