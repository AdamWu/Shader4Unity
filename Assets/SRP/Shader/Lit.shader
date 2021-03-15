Shader "Custom Pipeline/Lit" {
	
	Properties {
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex("Albedo & Alpha", 2D) = "white" {}
		_Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
		[Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
		[Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1
		[KeywordEnum(On, Clip, Dither, Off)] _Shadows("Shadows", Float) = 0

		_Metallic("Metallic", Range(0, 1)) = 0
		_Smoothness("Smoothness", Range(0, 1)) = 0.5

		[Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha("Premultiply Alpha", Float) = 0
		//[HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0, 0)

		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite("Z Write", Float) = 1
	}
	
	SubShader {
		Pass {
			Tags {
				"LightMode" = "CustomLit"
			}
			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]

			HLSLPROGRAM
			#pragma target 3.5
			
			#pragma shader_feature _CLIPPING
			#pragma shader_feature _PREMULTIPLY_ALPHA
			#pragma shader_feature _RECEIVE_SHADOWS
			#pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7		
			#pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER

			#pragma multi_compile_instancing

			/*
			#pragma multi_compile _ _SHADOWS_HARD
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _CASCADED_SHADOWS_HARD _CASCADED_SHADOWS_SOFT
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON
			#pragma multi_compile _ _SHADOWMASK _DISTANCE_SHADOWMASK
			*/

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			
			#include "../ShaderLibrary/Lit.hlsl"
			
			ENDHLSL
		}

		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}
			ColorMask 0
			
			HLSLPROGRAM
			#pragma target 3.5

			#pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER

			#pragma multi_compile_instancing

			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			
			#include "../ShaderLibrary/ShadowCaster.hlsl"
			
			ENDHLSL
		}

		/*
		Pass {
			Tags {
				"LightMode" = "Meta"
			}
			Cull Off
			HLSLPROGRAM
			#pragma target 3.5

			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment

			#include "../ShaderLibrary/Meta.hlsl"

			ENDHLSL
		}

		Pass {
			Tags {
				"LightMode" = "DepthOnly"
			}
			ColorMask 0
			Cull [_Cull]
			ZWrite On

			HLSLPROGRAM
			#pragma target 3.5

			#pragma multi_compile_instancing

			#pragma vertex DepthOnlyPassVertex
			#pragma fragment DepthOnlyPassFragment

			#include "../ShaderLibrary/DepthOnly.hlsl"

			ENDHLSL
		}
		*/ 
	}

	//CustomEditor "LitShaderGUI"
	CustomEditor "CustomShaderGUI"
}