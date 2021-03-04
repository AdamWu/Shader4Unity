#ifndef LIT_INCLUDED
#define LIT_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
// 2018 old
float4 unity_LightIndicesOffsetAndCount;
float4 unity_4LightIndices0, unity_4LightIndices1;
// 2019
real4 unity_LightData;
real4 unity_LightIndices[2]; // 4+4=8个 
CBUFFER_END

// light
#define MAX_VISIBLE_LIGHTS 16 
CBUFFER_START(_LightBuffer)
float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

// shadow
CBUFFER_START(_ShadowBuffer)
float4x4 _WorldToShadowMatrix;
CBUFFER_END
TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);

float ShadowAttenuation(float3 worldPos)
{
	float4 shadowPos = mul(_WorldToShadowMatrix, float4(worldPos, 1.0));
	shadowPos.xyz /= shadowPos.z;
	return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
}

#define UNITY_MATRIX_M unity_ObjectToWorld

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

UNITY_INSTANCING_BUFFER_START(PerInstance)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)

struct VertexInput {
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 pos : POSITION;
	float3 normal : NORMAL;
};

struct VertexOutput {
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float4 clipPos : SV_POSITION;
	float3 normal : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	float3 vertexLighting : TEXCOORD2;
};

float3 DiffuseLight(int index, float3 normal, float3 worldPos, float shadowAttenuation) {
	float3 lightColor = _VisibleLightColors[index].rgb;
	float4 lightDirectionOrPosition = _VisibleLightDirectionsOrPositions[index];
	float4 lightAttenuation = _VisibleLightAttenuations[index];
	float3 spotDirection = _VisibleLightSpotDirections[index];
	// dir
	float3 lightVector = lightDirectionOrPosition.xyz - worldPos * lightDirectionOrPosition.w;
	float3 lightDirection = normalize(lightVector);//lightDirectionOrPosition.xyz;
	float diffuse = saturate(dot(normal, lightDirection));
	
	// attenuation
	float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
	rangeFade = saturate(1 - rangeFade * rangeFade);
	rangeFade *= rangeFade;
	float spotFade = dot(spotDirection, lightDirection);
	spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
	spotFade *= spotFade;
	float distanceSqr = max(dot(lightVector, lightVector), 0.00001);
	diffuse *= shadowAttenuation * spotFade * rangeFade / distanceSqr;

	return diffuse * lightColor;
}

VertexOutput LitPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);
	output.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
	output.worldPos = worldPos;

	// 优化： 非重要4个光源
	output.vertexLighting = 0;
	for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++) {
		int lightIndex = unity_4LightIndices1[i - 4];
		output.vertexLighting = DiffuseLight(lightIndex, output.normal, output.worldPos, 1);
	}

	return output;
}

float4 LitPassFragment(VertexOutput input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);
	input.normal = normalize(input.normal);
	float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;

	float3 diffuseLight = input.vertexLighting;
	float shadowAttenuation = ShadowAttenuation(input.worldPos);
	for (int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++) {
		int lightIndex = unity_4LightIndices0[i];
		diffuseLight += DiffuseLight(lightIndex, input.normal, input.worldPos, shadowAttenuation);
	}

	float3 color = diffuseLight * albedo;
	return float4(color, 1);
}

#endif