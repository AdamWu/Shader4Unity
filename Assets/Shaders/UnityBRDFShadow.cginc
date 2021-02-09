#if !defined(UNITY_BRDF_SHADOW_INCLUDED)
#define UNITY_BRDF_SHADOW_INCLUDED

#include "UnityCG.cginc"

#if defined(_RENDERING_CUTOUT) && !defined(_SMOOTHNESS_ALBEDO)
#define SHADOWS_NEED_UV 1
#endif

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;
float _AlphaCutoff;

struct VertexData {
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

struct Interpolators {
	float4 position : SV_POSITION;
#if SHADOWS_NEED_UV
	float2 uv : TEXCOORD0;
#endif
	float3 lightVec : TEXCOORD1;
};

float GetAlpha(Interpolators i) {
	float alpha = _Tint.a;
#if SHADOWS_NEED_UV
	alpha *= tex2D(_MainTex, i.uv.xy).a;
#endif
	return alpha;
}

#if defined(SHADOWS_CUBE)
	Interpolators ShadowVertexProgram(VertexData v) {
		Interpolators i;
		i.position = UnityObjectToClipPos(v.position);
	#if SHADOWS_NEED_UV
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif
		i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
		return i;
	}

	float4 ShadowFragmentProgram(Interpolators i) : SV_TARGET{
		
		float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif

		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;
		return UnityEncodeCubeShadowDepth(depth);
	}
#else

	Interpolators ShadowVertexProgram(VertexData v) {
		Interpolators i;
		i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
		i.position = UnityApplyLinearShadowBias(i.position);
#if SHADOWS_NEED_UV
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
#endif
		i.lightVec = float3(0, 0, 1);
		return i;
	}

	half4 ShadowFragmentProgram(Interpolators i) : SV_TARGET {
		float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif
		return 0;
	}
#endif

#endif
