using UnityEngine;

public class InstancedMaterialProperties  : MonoBehaviour {

	[SerializeField]
	Color color = Color.white;
    [SerializeField, Range(0f, 1f)]
    float smothness = 0.5f;

    static MaterialPropertyBlock propertyBlock;

    static int colorID = Shader.PropertyToID("_Color");
    static int smoothnessID = Shader.PropertyToID("_Smoothness");

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
        propertyBlock.SetFloat(smoothnessID, smothness);

        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }
}