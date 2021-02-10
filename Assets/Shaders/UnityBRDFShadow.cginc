#if !defined(UNITY_BRDF_SHADOW_INCLUDED)
#define UNITY_BRDF_SHADOW_INCLUDED

#include "UnityCG.cginc"

#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	#define SHADOWS_SEMITRANSPARENT 1
#endif

#if defined(_RENDERING_CUTOUT) || defined(SHADOWS_SEMITRANSPARENT)
	#if !defined(_SMOOTHNESS_ALBEDO)
	#define SHADOWS_NEED_UV 1
	#endif
#endif

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;
float _AlphaCutoff;

sampler3D _DitherMaskLOD;

struct VertexData {
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

struct InterpolatorsVertex {
	float4 position : SV_POSITION;
#if SHADOWS_NEED_UV
	float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
	float3 lightVec : TEXCOORD1;
#endif
};

struct Interpolators {
#if SHADOWS_SEMITRANSPARENT
	UNITY_VPOS_TYPE vpos : VPOS;
#else
	float4 position : SV_POSITION;
#endif
#if SHADOWS_NEED_UV
	float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
	float3 lightVec : TEXCOORD1;
#endif
};

float GetAlpha(Interpolators i) {
	float alpha = _Tint.a;
#if SHADOWS_NEED_UV
	alpha *= tex2D(_MainTex, i.uv.xy).a;
#endif
	return alpha;
}

InterpolatorsVertex ShadowVertexProgram(VertexData v)
{
	InterpolatorsVertex i;
#if defined(SHADOWS_CUBE)
	i.position = UnityObjectToClipPos(v.position);
	i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
#else
	i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
	i.position = UnityApplyLinearShadowBias(i.position);
#endif

#if SHADOWS_NEED_UV
	i.uv = TRANSFORM_TEX(v.uv, _MainTex);
#endif
	return i;
}

float4 ShadowFragmentProgram(Interpolators i) : SV_TARGET
{		
	float alpha = GetAlpha(i);
#if defined(_RENDERING_CUTOUT)
	clip(alpha - _AlphaCutoff);
#endif
	
#if defined(SHADOWS_SEMITRANSPARENT)
	float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a;
	clip(dither - 0.01);
	//clip(1);
#endif

#if defined(SHADOWS_CUBE)
	float depth = length(i.lightVec) + unity_LightShadowBias.x;
	depth *= _LightPositionRange.w;
	return UnityEncodeCubeShadowDepth(depth);
#else
	return 0;
#endif
}

#endif
