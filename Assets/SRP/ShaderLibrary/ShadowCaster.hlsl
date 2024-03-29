#ifndef SHADOWCASTER_INCLUDED
#define SHADOWCASTER_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
real4 unity_WorldTransformParams;
CBUFFER_END

CBUFFER_START(_ShadowCasterBuffer)
float _ShadowBias;
CBUFFER_END

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

#define UNITY_MATRIX_M unity_ObjectToWorld

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

/*
UNITY_INSTANCING_BUFFER_START(PerInstance)
UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(PerInstance)
*/
CBUFFER_START(UnityPerMaterial)
float4 _Color;
float4 _MainTex_ST;
float _Cutoff;
CBUFFER_END

struct VertexInput {
	float4 pos : POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos : SV_POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

VertexOutput ShadowCasterPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);
#if UNITY_REVERSED_Z
	//output.clipPos.z -= _ShadowBias;
	output.clipPos.z = min(output.clipPos.z, output.clipPos.w * UNITY_NEAR_CLIP_VALUE);
#else
	//output.clipPos.z += _ShadowBias;
	output.clipPos.z = max(output.clipPos.z, output.clipPos.w * UNITY_NEAR_CLIP_VALUE);
#endif

	output.uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;

	return output;
}

void ShadowCasterPassFragment(VertexOutput input) {
	UNITY_SETUP_INSTANCE_ID(input);
	float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
	float4 finalColor = texColor * _Color;

#if defined(_SHADOWS_CLIP)
	clip(finalColor.a - UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Cutoff));
#elif defined(_SHADOWS_DITHER)
	float dither = InterleavedGradientNoise(input.clipPos.xy, 0);
	clip(finalColor.a - dither);
#endif
}

#endif