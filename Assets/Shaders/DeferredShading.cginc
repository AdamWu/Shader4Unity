#if !defined(DEFERRED_SHADING)
#define DEFERRED_SHADING

#include "UnityPBSLighting.cginc"

struct VertexData {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
};

struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 ray : TEXCOORD1;
};

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

float4 _LightColor, _LightDir;
sampler2D _ShadowMapTexture;

sampler2D _LightTexture0;
float4x4 unity_WorldToLight;

Interpolators VertexProgram(VertexData v) {
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.uv = ComputeScreenPos(i.pos);
	i.ray = v.normal;
	return i;
}

UnityLight CreateLight(float2 uv, float3 worldPos, float viewZ) {
	UnityLight light;
	light.dir = -_LightDir;
	float attenuation = 1;
	float shadowAttenuation = 1;
#if defined(DIRECTIONAL_COOKIE)
	float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
	attenuation *= tex2D(_LightTexture0, uvCookie).w;
#endif
#if defined(SHADOWS_SCREEN)
	shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;
	float shadowFadeDistance = UnityComputeShadowFadeDistance(worldPos, viewZ);
	float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
	shadowAttenuation = saturate(shadowAttenuation + shadowFade);
#endif
	light.color = _LightColor.rgb * attenuation * shadowAttenuation;
	return light;
}

float4 FragmentProgram(Interpolators i) : SV_Target {
	float2 uv = i.uv.xy / i.uv.w;
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth(depth);
	float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;
	float3 viewPos = rayToFarPlane * depth;
	float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;
	float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
	
	float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
	float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
	float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
	float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
	float oneMinusReflectivity = 1 - SpecularStrength(specularTint);

	UnityLight light = CreateLight(uv, worldPos, viewPos.z);
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	float4 color = UNITY_BRDF_PBS(
		albedo, specularTint, oneMinusReflectivity, smoothness,
		normal, viewDir, light, indirectLight
	);

#if !defined(UNITY_HDR_ON)
	color = exp2(-color);
#endif
	return color;
}

#endif