Shader "Custom/UnityBRDF"
{
	Properties
	{ 
		_Color("Color",Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		_Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
		[NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}
		[Gamma] _Metallic("Metallic", Range(0,1)) = 0
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1
		[NoScaleOffset] _EmissionMap("Emission", 2D) = "black" {}
		_Emission("Emission", Color) = (0, 0, 0)
		[NoScaleOffset] _OcclusionMap("Occlusion", 2D) = "white" {}
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1
		[NoScaleOffset] _DetailMask("Detail Mask", 2D) = "white" {}

		_DetailTex("Detail Albedo", 2D) = "white" {}
		_DetailNormalMap("Detail Normal Map", 2D) = "bump" {}
		_DetailBumpScale("Detail Bump Scale", Float) = 1


		[HideInInspector] _SrcBlend("_SrcBlend", Float) = 1
		[HideInInspector] _DstBlend("_DstBlend", Float) = 0
		[HideInInspector] _ZWrite("_ZWrite", Float) = 1
	}
	SubShader
	{
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target 3.0

			#define FORWARD_BASE_PASS
			#pragma multi_compile _ VERTEXLIGHT_ON	// for vertex light
			#pragma multi_compile _ SHADOWS_SCREEN	// only for directional light
			#pragma multi_compile_fwdbase // SHADOWS_SCREEN LIGHTMAP_ON DIRLIGHTMAP_COMBINED ...
			#pragma multi_compile_fog

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP


			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}
		
		//  Additive forward pass (one light per pass)
		Pass
		{
			Tags{"LightMode" = "ForwardAdd"}

			Blend [_SrcBlend] One
			ZWrite Off

			CGPROGRAM
			#pragma target 3.0
			 
			// different light variant
			#pragma multi_compile DIRECTIONAL POINT SPOT
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			//#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}

		// Deferred pass
		Pass {
			Tags {
				"LightMode" = "Deferred"
			}
			CGPROGRAM

			#pragma target 3.0
			#pragma exclude_renderers nomrt

			#define DEFERRED_PASS
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_prepassfinal

			#pragma shader_feature _ _RENDERING_CUTOUT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}

		// Shadow rendering pass
		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM
			#pragma target 3.0

			#pragma multi_compile_shadowcaster

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SMOOTHNESS_ALBEDO

			#pragma vertex ShadowVertexProgram
			#pragma fragment ShadowFragmentProgram

			#include "UnityBRDFShadow.cginc"

			ENDCG
		}

		// used for lightmapping
		Pass {
			Tags {
				"LightMode" = "Meta"
			}

			Cull Off

			CGPROGRAM

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP

			#pragma vertex LightmappingVertexProgram
			#pragma fragment LightmappingFragmentProgram

			#include "UnityBRDFLightmapping.cginc"

			ENDCG
		}
	}

	CustomEditor "UnityBRDFLightingShaderGUI"
}
