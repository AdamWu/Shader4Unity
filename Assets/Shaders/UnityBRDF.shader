Shader "Custom/UnityBRDF"
{
	Properties
	{
		_Tint("Tint",Color) = (1,1,1,1)
		_MainTex("Texture", 2D) = "white" {}
		_Metallic("Metallic",Range(0,1)) = 0
		_Smoothness("Smoothness",Range(0,1)) = 0
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
			#pragma multi_compile VERTEXLIGHT_ON

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

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityBRDFLighting.cginc"

			ENDCG
		}
	}
}
