#if !defined(UNITY_BRDF_LIGHTING_INCLUDED)
#define UNITY_BRDF_LIGHTING_INCLUDED

#include "UnityBRDFLightingCommon.cginc"

#if !defined(ALBEDO_FUNCTION)
#define ALBEDO_FUNCTION GetAlbedo
#endif

v2f vert(a2v v)
{
	v2f o;
	UNITY_INITIALIZE_OUTPUT(v2f, o);
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, o);

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

FragmentOutput frag(v2f i)
{
	UNITY_SETUP_INSTANCE_ID(i);

	float alpha = GetAlpha(i);
#if defined(_RENDERING_CUTOUT)
	clip(alpha - _Cutoff);
#endif

	InitializeFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
	//float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));

	half3 specColor;
	half oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(ALBEDO_FUNCTION(i), GetMetallic(i), specColor, oneMinusReflectivity);
	
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
