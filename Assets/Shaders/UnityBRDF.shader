Shader "Custom/UnityBRDF"
{
	Properties
	{
		_Tint("Tint",Color) = (1,1,1,1)
		_MainTex("Texture", 2D) = "white" {}
		_Metallic("Metallic", Range(0,1)) = 0
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		_NormalMap("Bump Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1
	}
	SubShader
	{
		Pass
		{
			Tags{"LightMode" = "ForwardBase"}
				
			CGPROGRAM
			#pragma target 3.0

			#define FORWARD_BASE_PASS
			#pragma multi_compile _ VERTEXLIGHT_ON	// for vertex light
			#pragma multi_compile _ SHADOWS_SCREEN	// only for directional light

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
}
