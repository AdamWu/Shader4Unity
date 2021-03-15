Shader "Custom Pipeline/Unlit"
{
    Properties
    {
		_Color("Color", Color) = (1, 1, 1, 1)
		_MainTex("Albedo & Alpha", 2D) = "white" {}
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		[Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
		[Enum(Off, 0, ON, 1)] _ZWrite("Z Write", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        
		Pass{
			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]

			HLSLPROGRAM
			#pragma target 3.5

			#pragma multi_compile_instancing
			#pragma shader_feature _CLIPPING

			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			#include "../ShaderLibrary/Unlit.hlsl" 

			ENDHLSL
		}
    }
}
