// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(UNITY_BRDF_LIGHTING_INCLUDED)
#define UNITY_BRDF_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	#if !defined(FOG_DISTANCE)
		#define FOG_DEPTH 1
	#endif
	#define FOG_ON 1
#endif

#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
	#if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
		#define SUBTRACTIVE_LIGHTING 1
	#endif
#endif

struct a2v
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
};

struct v2f
{
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;

#if defined(BINORMAL_PER_FRAGMENT)
	float4 tangent : TEXCOORD2;
#else
	float3 tangent : TEXCOORD2;
	float3 binormal : TEXCOORD3;
#endif

#if FOG_DEPTH
	float4 worldPos : TEXCOORD4;
#else
	float3 worldPos : TEXCOORD4;
#endif

	UNITY_SHADOW_COORDS(5)
#if defined(VERTEXLIGHT_ON)
	float3 vertexLightColor : TEXCOORD6;
#endif
#if defined(LIGHTMAP_ON)
	float2 lightmapUV : TEXCOORD6;
#endif
#if defined(DYNAMICLIGHTMAP_ON)
	float2 dynamicLightmapUV : TEXCOORD7;
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

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
	return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
}

v2f vert(a2v v)
{
	v2f o;
	UNITY_INITIALIZE_OUTPUT(v2f, o);
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
#if FOG_DEPTH
	o.worldPos.w = o.pos.z;
#endif
	o.normal = UnityObjectToWorldNormal(v.normal);
#if defined(BINORMAL_PER_FRAGMENT)
	o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
#else
	o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
	o.binormal = CreateBinormal(o.normal, o.tangent.xyz, o.tangent.w);
#endif

	UNITY_TRANSFER_SHADOW(o, v.uv1);

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
#if defined(DYNAMICLIGHTMAP_ON)
	o.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
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

float FadeShadows(v2f i, float attenuation)
{
#if HANDLE_SHADOWS_BLENDING_IN_GI
	float viewZ = dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
	float shadowFadeDistance = UnityComputeShadowFadeDistance(i.worldPos, viewZ);
	float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
	float bakedAttenuation = UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
	//attenuation = saturate(attenuation + shadowFade);
	attenuation = UnityMixRealtimeAndBakedShadows(attenuation, bakedAttenuation, shadowFade);
#endif
	return attenuation;
}
void ApplySubtractiveLighting(v2f i, inout UnityIndirect indirectLight)
{
#if SUBTRACTIVE_LIGHTING
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
	attenuation = FadeShadows(i, attenuation);
	float ndotl = saturate(dot(i.normal, _WorldSpaceLightPos0.xyz));
	float3 shadowedLightEstimate = ndotl * (1 - attenuation) * _LightColor0.rgb;
	float3 subtractedLight = indirectLight.diffuse - shadowedLightEstimate;
	subtractedLight = max(subtractedLight, unity_ShadowColor.rgb);
	subtractedLight = lerp(subtractedLight, indirectLight.diffuse, _LightShadowData.x);
	indirectLight.diffuse = min(subtractedLight, indirectLight.diffuse);
#endif
}

UnityLight CreateLight(v2f i)
{
	UnityLight light;

#if defined(DEFERRED_PASS) || SUBTRACTIVE_LIGHTING
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
	attenuation = FadeShadows(i, attenuation);
	light.color = _LightColor0.rgb * attenuation;
#endif
	return light;
}

float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
	UNITY_BRANCH
	if (cubemapPosition.w > 0) {
		float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
		float scalar = min(min(factors.x, factors.y), factors.z);
		direction = direction * scalar + (position - cubemapPosition);
	}
	return direction;
}

UnityIndirect CreateIndirectLight(v2f i, float3 viewDir) {
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	// four vertex light
#if defined(VERTEXLIGHT_ON)
	indirectLight.diffuse = i.vertexLightColor;
#endif

	// other light info
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
	// baked lightmap
	#if defined(LIGHTMAP_ON)
		indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
		#if defined(DIRLIGHTMAP_COMBINED)
			float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV);
			indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, lightmapDirection, i.normal);
		#endif
		ApplySubtractiveLighting(i, indirectLight);
	#endif
	// dynamic lightmap
	#if defined(DYNAMICLIGHTMAP_ON)
		float3 dynamicLightDiffuse = DecodeRealtimeLightmap(UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV));
		#if defined(DIRLIGHTMAP_COMBINED)
			float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap,i.dynamicLightmapUV);
			indirectLight.diffuse += DecodeDirectionalLightmap(dynamicLightDiffuse, dynamicLightmapDirection, i.normal);
		#else
			indirectLight.diffuse += dynamicLightDiffuse;
		#endif
	#endif

	// SH light
	#if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)
		#if UNITY_LIGHT_PROBE_PROXY_VOLUME
			if (unity_ProbeVolumeParams.x == 1) {
				indirectLight.diffuse = SHEvalLinearL0L1_SampleProbeVolume(float4(i.normal, 1), i.worldPos);
				indirectLight.diffuse = max(0, indirectLight.diffuse);
				#if defined(UNITY_COLORSPACE_GAMMA)
					indirectLight.diffuse = LinearToGammaSpace(indirectLight.diffuse);
				#endif
			}
			else {
				indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
			}
		#else
			indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
		#endif
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

	// if suppored spec cube blending
	#if UNITY_SPECCUBE_BLENDING
		float interpolater = unity_SpecCube0_BoxMin.w;
		UNITY_BRANCH
		if (interpolater < 0.99999) {
			float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube1_HDR, envData);
			indirectLight.specular = lerp(probe1, probe0, interpolater);
		} else {
			indirectLight.specular = probe0;
		}
	#else
		indirectLight.specular = probe0;
	#endif

	// occlusion
	float occlusion = GetOcclusion(i);
	indirectLight.diffuse *= occlusion;
	indirectLight.specular *= occlusion;
#endif
	return indirectLight;
}

void InitializeFragmentNormal(inout v2f i)
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

#if defined(BINORMAL_PER_FRAGMENT)
	float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
#else
	float3 binormal = i.binormal;
#endif
		
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
	);
}

float4 ApplyFog(float4 color, v2f i) {
#if FOG_ON
	float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
	#if FOG_DEPTH
		viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
	#endif
	UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
	unityFogFactor = saturate(unityFogFactor);
	float3 fogColor = 0;
	#if defined(FORWARD_BASE_PASS)
		fogColor = unity_FogColor.rgb;
	#endif
	color.rgb = lerp(fogColor, color.rgb, unityFogFactor);
#endif
	return color;
}

struct FragmentOutput {
#if defined(DEFERRED_PASS)
	float4 gBuffer0 : SV_Target0;
	float4 gBuffer1 : SV_Target1;
	float4 gBuffer2 : SV_Target2;
	float4 gBuffer3 : SV_Target3;
	#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
		float4 gBuffer4 : SV_Target4;
	#endif
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

	InitializeFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
	//float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));

	half3 specColor;
	half oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), specColor, oneMinusReflectivity);
	
#if defined(_RENDERING_TRANSPARENT)
	albedo *= alpha;
	alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
#endif

	float4 color = UNITY_BRDF_PBS(
		albedo, specColor,
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir, 
		CreateLight(i), 
		CreateIndirectLight(i, viewDir)
	);

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

	#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
		float2 shadowUV = 0;
		#if defined(LIGHTMAP_ON)
			shadowUV = i.lightmapUV;
		#endif
		output.gBuffer4 = UnityGetRawBakedOcclusions(shadowUV, i.worldPos.xyz);
	#endif
#else
	output.color = ApplyFog(color, i);
#endif
	return output;
}

#endif
