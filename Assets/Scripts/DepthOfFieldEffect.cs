using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class DepthOfFieldEffect : MonoBehaviour
{
    const int circleOfConfusionPass = 0;

    public Shader dofShader;
    [Range(0.1f, 100f)]
    public float focusDistance = 10f;
    [Range(0.1f, 10f)]
    public float focusRange = 3f;

    Material dofMaterial = null;

    private void OnEnable()
    {
        //GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnDisable()
    {
        //GetComponent<Camera>().depthTextureMode &= ~DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (dofMaterial == null)
        {
            dofMaterial = new Material(dofShader);
            dofMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        dofMaterial.SetFloat("_FocusDistance", focusDistance);
        dofMaterial.SetFloat("_FocusRange", focusRange);

        Graphics.Blit(source, destination, dofMaterial, circleOfConfusionPass);
    }

}