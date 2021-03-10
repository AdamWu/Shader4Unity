using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Rendering;
using UnityEditor.Callbacks;

public class CustomPipelineShaderPreprocessor : IPreprocessShaders
{
    static CustomPipelineShaderPreprocessor instance;

    static ShaderKeyword cascadedShadowsHardKeyword = new ShaderKeyword("_CASCADED_SHADOWS_HARD");
    static ShaderKeyword cascadedShadowsSoftKeyword = new ShaderKeyword("_CASCADED_SHADOWS_SOFT");

    public int callbackOrder { get { return 0; } }

    CustomPipelineAsset pipelineAsset;
    int shaderVariantCount, strippedCount;

    //
    bool stripCascadedShadows;

    public CustomPipelineShaderPreprocessor()
    {
        instance = this;
        pipelineAsset = GraphicsSettings.renderPipelineAsset as CustomPipelineAsset;
        if (pipelineAsset == null) return;

        stripCascadedShadows = !pipelineAsset.HasShadowCascades;
    }

    public void OnProcessShader(Shader shader, ShaderSnippetData snippet, IList<ShaderCompilerData> data)
    {
        if (pipelineAsset == null) return;

        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        sb.AppendFormat("shader={3}, passType={0}, passName={1}, shaderType={2}\n",
            snippet.passType, snippet.passName, snippet.shaderType, shader.name);

        for (int i = 0; i < data.Count; ++i)
        {
            var pdata = data[i];
            sb.AppendFormat("{0}.{1},{2}: ", i, pdata.graphicsTier, pdata.shaderCompilerPlatform);
            var ks = pdata.shaderKeywordSet.GetShaderKeywords();
            foreach (var k in ks)
            {
                sb.AppendFormat("{0}, ", k.GetKeywordName());
            }
            sb.Append("\n");
        }
        Debug.Log(sb.ToString());

        // strip 
        for (int i = 0; i < data.Count; ++i)
        {
            if (Strip(data[i]))
            {
                data.RemoveAt(i--);
                strippedCount++;
            }
        }

        shaderVariantCount += data.Count;
    }

    bool Strip(ShaderCompilerData data)
    {
        return
            stripCascadedShadows && (
                data.shaderKeywordSet.IsEnabled(cascadedShadowsHardKeyword) ||
                data.shaderKeywordSet.IsEnabled(cascadedShadowsSoftKeyword)
            );
    }

    [PostProcessBuild(0)]
    static void LogVariantCount(BuildTarget target, string path)
    {
        instance.LogVariantCount();
        instance = null;
    }
    
    void LogVariantCount()
    {
        if (pipelineAsset == null) return;

        int finalCount = shaderVariantCount - strippedCount;
        int percentage = Mathf.RoundToInt(100f * finalCount / shaderVariantCount);

        Debug.Log("Included " + finalCount +" shader variants out of "+ shaderVariantCount + " ("+percentage+"%).");
    }

}