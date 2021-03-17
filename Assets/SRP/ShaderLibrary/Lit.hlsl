#ifndef LIT_INCLUDED
#define LIT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl" 
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
real4 unity_WorldTransformParams;

//float4 unity_LightmapST;
//float4 unity_DynamicLightmapST;
float4 unity_SHAr;
float4 unity_SHAg;
float4 unity_SHAb;
float4 unity_SHBr;
float4 unity_SHBg;
float4 unity_SHBb;
float4 unity_SHC;
CBUFFER_END

float3 _WorldSpaceCameraPos;

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

UNITY_INSTANCING_BUFFER_START(PerInstance)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_INSTANCING_BUFFER_END(PerInstance)


struct VertexInput {
	float4 pos : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
	GI_ATTRIBUTE_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos : SV_POSITION;
	float3 normal : TEXCOORD0; 
	float2 uv : TEXCOORD1;
	float3 worldPos : TEXCOORD3;
	GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

VertexOutput LitPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	TRANSFER_GI_DATA(input, output);
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);
#if defined(UNITY_ASSUME_UNIFORM_SCALING)
	output.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
#else
	output.normal = normalize(mul(input.normal, (float3x3)UNITY_MATRIX_I_M));
#endif
	output.worldPos = worldPos.xyz;

	float4 ST = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _MainTex_ST);
	output.uv = input.uv * ST.xy + ST.zw;
	return output;
}

float4 LitPassFragment(VertexOutput input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	input.normal = normalize(input.normal);
	float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color);
	float4 finalColor = texColor * baseColor;

#if defined(_CLIPPING)
	clip(finalColor.a - UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Cutoff));
#endif

	Surface surface;
	surface.position = input.worldPos;
	surface.normal = input.normal;
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.worldPos);
	surface.depth = -TransformWorldToView(input.worldPos).z;
	surface.color = finalColor.rgb;
	surface.alpha = finalColor.a;
	surface.metallic = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Metallic);
	surface.smoothness = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Smoothness);
	surface.dither = InterleavedGradientNoise(input.clipPos.xy, 0);

#if defined(_PREMULTIPLY_ALPHA)
	BRDF brdf = GetBRDF(surface, true);
#else
	BRDF brdf = GetBRDF(surface);
#endif
	GI gi = GetGI(GI_FRAGMENT_DATA(input), surface);
	float3 color = GetLighting(surface, brdf, gi);
	return float4(color, surface.alpha);

	//return finalColor;
}

#endif