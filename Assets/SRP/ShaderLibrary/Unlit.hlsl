#ifndef UNLIT_INCLUDED
#define UNLIT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
CBUFFER_END

struct VertexInput {
	float4 pos : POSITION;
};

struct VertexOutput {
	float4 clipPos : SV_POSITION;
};

VertexOutput UnlitPassVertex(VertexInput input) {
	VertexOutput output;
	float4 wpos = mul(unity_ObjectToWorld, input.pos);
	output.clipPos = mul(unity_MatrixVP, wpos);
	return output;
}

float4 UnlitPassFragment(VertexOutput input) : SV_TARGET {
	return 1;
}

#endif