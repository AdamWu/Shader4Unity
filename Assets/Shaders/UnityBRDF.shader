Shader "Custom/UnityBRDF"
{
	Properties
	{
		_Tint("Tint",Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		[NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}
		[Gamma] _Metallic("Metallic", Range(0,1)) = 0
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		_NormalMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1
		[NoScaleOffset] _EmissionMap("Emission", 2D) = "black" {}
		_Emission("Emission", Color) = (0, 0, 0)

		_DetailTex("Detail Albedo", 2D) = "white" {}
		_DetailNormalMap("Detail Normal Map", 2D) = "bump" {}
		_DetailBumpScale("Detail Bump Scale", Float) = 1
	}
	SubShader
	{
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
				
			CGPROGRAM
			#pragma target 3.0

			#define FORWARD_BASE_PASS
			#pragma multi_compile __ VERTEXLIGHT_ON	// for vertex light
			#pragma multi_compile __ SHADOWS_SCREEN	// only for directional light

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}

		Pass
		{
			Tags{"LightMode" = "ForwardAdd"}

			Blend One One
			ZWrite Off

			CGPROGRAM
			#pragma target 3.0
			 
			// different light variant
			#pragma multi_compile DIRECTIONAL POINT SPOT
			#pragma multi_compile_fwdadd_fullshadows	// for all lights

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}

		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM
			#pragma target 3.0

			#pragma multi_compile_shadowcaster

			#pragma vertex ShadowVertexProgram
			#pragma fragment ShadowFragmentProgram

			#include "UnityBRDFShadow.cginc"

			ENDCG
		}
	}

	CustomEditor "UnityBRDFLightingShaderGUI"
}
