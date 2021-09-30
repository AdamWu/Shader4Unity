using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class SSAOEffect : MonoBehaviour
{
    public enum SSAOPassName
    {
        GenerateAO = 0,
        BilateralFilter = 1,
        Composite = 2,
        Noise = 3,
    }

    public Texture Nosie;
    [Range(0.010f, 1.0f)]
    public float SampleKernelRadius = 1f;
    [Range(4, 64)]
    public int SampleKernelCount = 64;

    [Range(1, 4)]
    public int BlurRadius = 2;
    [Range(0, 0.2f)]
    public float BilaterFilterStrength = 0.2f;

    public bool OnlyShowAO = false;

    [HideInInspector]
    public Shader ssaoShader;
    
    private Material ssaoMaterial = null;
    private Camera currentCamera = null;
    private List<Vector4> sampleKernelList = new List<Vector4>();

    private void Awake()
    {
        currentCamera = GetComponent<Camera>();
    }

    private void OnEnable()
    {
        currentCamera.depthTextureMode |= DepthTextureMode.DepthNormals;
    }

    private void OnDisable()
    {
        currentCamera.depthTextureMode &= ~DepthTextureMode.DepthNormals;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (ssaoMaterial == null)
        {
            ssaoMaterial = new Material(ssaoShader);
            ssaoMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        GenerateAOSampleKernel();

        var aoRT = RenderTexture.GetTemporary(source.width, source.height, 0);
        //把噪声图筛进去
        ssaoMaterial.SetTexture("_NoiseTex", Nosie);
        ssaoMaterial.SetFloat("Height", (float)Screen.height);
        ssaoMaterial.SetFloat("Width", (float)Screen.width);
        ssaoMaterial.SetMatrix("_InverseProjectionMatrix", currentCamera.projectionMatrix.inverse);
        ssaoMaterial.SetVectorArray("_SampleKernelArray", sampleKernelList.ToArray());
        ssaoMaterial.SetFloat("_SampleKernelCount", sampleKernelList.Count);
        ssaoMaterial.SetFloat("_SampleKeneralRadius", SampleKernelRadius);
        Graphics.Blit(source, aoRT, ssaoMaterial, (int)SSAOPassName.GenerateAO);

        var blurRT = RenderTexture.GetTemporary(source.width, source.height, 0);
        ssaoMaterial.SetFloat("_BilaterFilterFactor", 1.0f - BilaterFilterStrength);

        ssaoMaterial.SetVector("_BlurRadius", new Vector4(BlurRadius, 0, 0, 0));
        Graphics.Blit(aoRT, blurRT, ssaoMaterial, (int)SSAOPassName.BilateralFilter);

        ssaoMaterial.SetVector("_BlurRadius", new Vector4(0, BlurRadius, 0, 0));
        if (OnlyShowAO)
        {
            Graphics.Blit(blurRT, destination, ssaoMaterial, (int)SSAOPassName.BilateralFilter);
        }
        else
        {
            Graphics.Blit(blurRT, aoRT, ssaoMaterial, (int)SSAOPassName.BilateralFilter);
            ssaoMaterial.SetTexture("_AOTex", aoRT);
            Graphics.Blit(source, destination, ssaoMaterial, (int)SSAOPassName.Composite);
        }

        RenderTexture.ReleaseTemporary(aoRT);
        RenderTexture.ReleaseTemporary(blurRT);
    }

    private void GenerateAOSampleKernel()
    {
        if (SampleKernelCount == sampleKernelList.Count)
            return;

        sampleKernelList.Clear();
        for (int i = 0; i < SampleKernelCount; i++)
        {
            var vec = new Vector4(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(0, 1.0f), 1.0f);
            vec.Normalize();
            var scale = (float)i / SampleKernelCount;
            //使分布符合二次方程的曲线
            scale = Mathf.Lerp(0.01f, 1.0f, scale * scale);
            vec *= scale;
            sampleKernelList.Add(vec);
        }
    }

}