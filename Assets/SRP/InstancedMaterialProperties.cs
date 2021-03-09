using UnityEngine;

public class InstancedMaterialProperties  : MonoBehaviour {

	[SerializeField]
	Color color = Color.white;
    [SerializeField, Range(0f, 1f)]
    float metallic = 0.0f;
    [SerializeField, Range(0f, 1f)]
    float smothness = 0.5f;
    [SerializeField, ColorUsage(false, true)]
    Color emissionColor = Color.black;

    static MaterialPropertyBlock propertyBlock;

    static int colorID = Shader.PropertyToID("_Color");
    static int metallicID = Shader.PropertyToID("_Metallic");
    static int smoothnessID = Shader.PropertyToID("_Smoothness");
    static int emissionColorId = Shader.PropertyToID("_EmissionColor");

    void Awake()
    {
        OnValidate();
    }

    void OnValidate()
    {
        if (propertyBlock == null)
        {
            propertyBlock = new MaterialPropertyBlock();
        }
        propertyBlock.SetColor(colorID, color);
        propertyBlock.SetFloat(metallicID, metallic);
        propertyBlock.SetFloat(smoothnessID, smothness);
        propertyBlock.SetColor(emissionColorId, emissionColor);

        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }

    void Update()
    {
        Color originalEmissionColor = emissionColor;
        emissionColor *= 0.5f + 0.5f * Mathf.Cos(2f * Mathf.PI * 0.2f * Time.time);
        OnValidate();
        //GetComponent<MeshRenderer>().UpdateGIMaterials();
        DynamicGI.SetEmissive(GetComponent<MeshRenderer>(), emissionColor);
        emissionColor = originalEmissionColor;
    }
}