// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(UNITY_BRDF_LIGHTING_INCLUDED)
#define UNITY_BRDF_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
#define FOG_DEPTH 1
#endif

struct a2v
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
};

struct v2f
{
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;
	float4 tangent : TEXCOORD2;
#if FOG_DEPTH
	float4 worldPos : TEXCOORD3;
#else
	float3 worldPos : TEXCOORD3;
#endif
	SHADOW_COORDS(4)
#if defined(VERTEXLIGHT_ON)
	float3 vertexLightColor : TEXCOORD5;
#endif
#if defined(LIGHTMAP_ON)
	float2 lightmapUV : TEXCOORD5;
#endif
};

float4 _Color;
float _Cutoff;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;
sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;
sampler2D _EmissionMap;
float3 _Emission;
sampler2D _OcclusionMap;
float _OcclusionStrength;

v2f vert(a2v v)
{
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
#if FOG_DEPTH
	o.worldPos.w = o.pos.z;
#endif
	o.normal = UnityObjectToWorldNormal(v.normal);
	o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

	TRANSFER_SHADOW(o);

#if defined(VERTEXLIGHT_ON)
	o.vertexLightColor = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb,
		unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, o.worldPos.xyz, o.normal
	);
#endif

#if defined(LIGHTMAP_ON)
	o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
#endif
	return o;
}

float GetMetallic(v2f i)
{
#if defined(_METALLIC_MAP)
	return tex2D(_MetallicMap, i.uv.xy).r;
#else
	return _Metallic;
#endif
}

float GetSmoothness(v2f i)
{
	float smoothness = 1;
#if defined(_SMOOTHNESS_ALBEDO)
	smoothness = tex2D(_MainTex, i.uv.xy).a;
#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
	smoothness = tex2D(_MetallicMap, i.uv.xy).a;
#endif
	return smoothness * _Smoothness;
}

float3 GetEmission(v2f i)
{
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
#if defined(_EMISSION_MAP)
	return tex2D(_EmissionMap, i.uv.xy) * _Emission;
#else
	return _Emission;
#endif
#else
	return 0;
#endif
}
float GetOcclusion(v2f i) {
#if defined(_OCCLUSION_MAP)
	return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
#else
	return 1;
#endif
}
float GetDetailMask(v2f i) {
#if defined (_DETAIL_MASK)
	return tex2D(_DetailMask, i.uv.xy).a;
#else
	return 1;
#endif
}
float3 GetAlbedo(v2f i) {
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
#if defined (_DETAIL_ALBEDO_MAP)
	float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
	albedo = lerp(albedo, albedo * details, GetDetailMask(i));
#endif
	return albedo;
}
float GetAlpha(v2f i) {
	float alpha = _Color.a;
#if !defined(_SMOOTHNESS_ALBEDO)
	alpha *= tex2D(_MainTex, i.uv.xy).a;
#endif
	return alpha;
}

UnityLight CreateLight(v2f i)
{
	UnityLight light;

#if defined(DEFERRED_PASS)
	light.dir = float3(0, 1, 0);
	light.color = 0;
#else

	#if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
		light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
	#else
		light.dir = _WorldSpaceLightPos0.xyz;
	#endif
	/*
	#if defined(SHADOWS_SCREEN)
		//float attenuation = tex2D(_ShadowMapTexture, i._ShadowCoord.xy / i._ShadowCoord.w);
		float attenuation = SHADOW_ATTENUATION(i);
	#else
		UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos.xyz);
	#endif
	*/
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
	//attenuation *= GetOcclusion(i);// direct light donnot need occlusion
	light.color = _LightColor0.rgb * attenuation;
#endif
	//light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

float3 BoxProjection(
	float3 direction, float3 position,
	float3 cubemapPosition, float3 boxMin, float3 boxMax
) {
	float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
	float scalar = min(min(factors.x, factors.y), factors.z);
	return direction * scalar + (position - cubemapPosition);
}

UnityIndirect CreateIndirectLight(v2f i, float3 viewDir) {
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	// four vertex light
#if defined(VERTEXLIGHT_ON)
	indirectLight.diffuse = i.vertexLightColor;
#endif
	// other SH light
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
	#if defined(LIGHTMAP_ON)
		indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
		#if defined(DIRLIGHTMAP_COMBINED)
			float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV);
			indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, lightmapDirection, i.normal);
		#endif
	#else
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
	#endif

	// reflection probes
	float3 reflectionDir = reflect(-viewDir, i.normal);
	Unity_GlossyEnvironmentData envData;
	envData.roughness = 1 - GetSmoothness(i);
	envData.reflUVW = BoxProjection(
		reflectionDir, i.worldPos.xyz,
		unity_SpecCube0_ProbePosition,
		unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
	);
	float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
	envData.reflUVW = BoxProjection(
		reflectionDir, i.worldPos.xyz,
		unity_SpecCube1_ProbePosition,
		unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
	);
	float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), unity_SpecCube1_HDR, envData);
	indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);

	// occlusion
	float occlusion = GetOcclusion(i);
	indirectLight.diffuse *= occlusion;
	indirectLight.specular *= occlusion;
#endif
	return indirectLight;
}

void CalculateFragmentNormal(inout v2f i)
{
	float3 tangentSpaceNormal = float3(0, 0, 1);
#if defined(_NORMAL_MAP)
	tangentSpaceNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
#endif
#if defined(_DETAIL_NORMAL_MAP)
	float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
	detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
	tangentSpaceNormal = BlendNormals(tangentSpaceNormal, detailNormal);
#endif

	float3 binormal = cross(i.normal, i.tangent.xyz) * (i.tangent.w * unity_WorldTransformParams.w);
	
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
	);
	i.normal = normalize(i.normal);
}

float4 ApplyFog(float4 color, v2f i) {
	float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
#if FOG_DEPTH
	viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
#endif
	UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
	unityFogFactor = saturate(unityFogFactor);
	// fog disabled
#if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
	unityFogFactor = 1;
#endif

	float3 fogColor = 0;
#if defined(FORWARD_BASE_PASS)
	fogColor = unity_FogColor.rgb;
#endif
	color.rgb = lerp(fogColor, color.rgb, unityFogFactor);
	return color;
}

struct FragmentOutput {
#if defined(DEFERRED_PASS)
	float4 gBuffer0 : SV_Target0;
	float4 gBuffer1 : SV_Target1;
	float4 gBuffer2 : SV_Target2;
	float4 gBuffer3 : SV_Target3;
#else
	float4 color : SV_Target;
#endif
};

FragmentOutput frag(v2f i)
{
	float alpha = GetAlpha(i);
#if defined(_RENDERING_CUTOUT)
	clip(alpha - _Cutoff);
#endif

	CalculateFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
	//float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));

	half3 specColor;
	half oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), specColor, oneMinusReflectivity);
	
#if defined(_RENDERING_TRANSPARENT)
	albedo *= alpha;
	alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
#endif

	float4 color = UNITY_BRDF_PBS(albedo,specColor,
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir, 
		CreateLight(i), CreateIndirectLight(i, viewDir));

	color.rgb += GetEmission(i);
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	color.a = alpha;
#endif

	FragmentOutput output;
#if defined(DEFERRED_PASS)
	#if !defined(UNITY_HDR_ON)
		color.rgb = exp2(-color.rgb);
	#endif
	output.gBuffer0.rgb = albedo;
	output.gBuffer0.a = GetOcclusion(i);
	output.gBuffer1.rgb = specColor;
	output.gBuffer1.a = GetSmoothness(i);
	output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
	output.gBuffer3 = color;
#else
	output.color = ApplyFog(color, i);
#endif
	return output;
}

#endif
