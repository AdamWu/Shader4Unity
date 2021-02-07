#if !defined(UNITY_BRDF_SHADOW_INCLUDED)
#define UNITY_BRDF_SHADOW_INCLUDED

#include "UnityCG.cginc"

struct VertexData {
	float4 position : POSITION;
	float3 normal : NORMAL;
};

#if defined(SHADOWS_CUBE)
	struct Interpolators {
		float4 position : SV_POSITION;
		float3 lightVec : TEXCOORD0;
	};
	Interpolators ShadowVertexProgram(VertexData v) {
		Interpolators i;
		i.position = UnityObjectToClipPos(v.position);
		i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
		return i;
	}

	float4 ShadowFragmentProgram(Interpolators i) : SV_TARGET{
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;
		return 0;//UnityEncodeCubeShadowDepth(depth);
	}
#else

	float4 ShadowVertexProgram(VertexData v) : SV_POSITION {
		float4 position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
		return UnityApplyLinearShadowBias(position);
	}

	half4 ShadowFragmentProgram() : SV_TARGET {
		return 0;
	}
#endif

#endif
