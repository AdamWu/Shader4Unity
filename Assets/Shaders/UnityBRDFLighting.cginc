// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(UNITY_BRDF_LIGHTING_INCLUDED)
#define UNITY_BRDF_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

struct a2v
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
};

struct v2f
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;
	float4 tangent : TEXCOORD2;
	float3 worldPos : TEXCOORD3;
	SHADOW_COORDS(4)
#if defined(VERTEXLIGHT_ON)
	float3 vertexLightColor : TEXCOORD5;
#endif
};

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;
fixed3 _Tint;
sampler2D _NormalMap;
float _BumpScale;
sampler2D _EmissionMap;
float3 _Emission;

v2f vert(a2v v)
{
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = TRANSFORM_TEX(v.uv, _MainTex);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex);
	o.normal = UnityObjectToWorldNormal(v.normal);
	o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

	TRANSFER_SHADOW(o);

#if defined(VERTEXLIGHT_ON)
	o.vertexLightColor = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb,
		unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, o.worldPos, o.normal
	);
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
#if defined(FORWARD_BASE_PASS)
#if defined(_EMISSION_MAP)
	return tex2D(_EmissionMap, i.uv.xy) * _Emission;
#else
	return _Emission;
#endif
#else
	return 0;
#endif
}

UnityLight CreateLight(v2f i)
{
	UnityLight light;

#if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
	light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
#else
	light.dir = _WorldSpaceLightPos0.xyz;
#endif

#if defined(SHADOWS_SCREEN)
	//float attenuation = tex2D(_ShadowMapTexture, i._ShadowCoord.xy / i._ShadowCoord.w);
	float attenuation = SHADOW_ATTENUATION(i);
#else
	UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
#endif
	// equal to this
	//UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);

	light.color = _LightColor0.rgb * attenuation;
	light.ndotl = DotClamped(i.normal, light.dir);
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
#if defined(FORWARD_BASE_PASS)
	indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));

	// reflection probes
	float3 reflectionDir = reflect(-viewDir, i.normal);
	Unity_GlossyEnvironmentData envData;
	envData.roughness = 1 - GetSmoothness(i);
	envData.reflUVW = BoxProjection(
		reflectionDir, i.worldPos,
		unity_SpecCube0_ProbePosition,
		unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
	);
	float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
	envData.reflUVW = BoxProjection(
		reflectionDir, i.worldPos,
		unity_SpecCube1_ProbePosition,
		unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
	);
	float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), unity_SpecCube1_HDR, envData);
	indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
#endif
	return indirectLight;
}

void CalculateFragmentNormal(inout v2f i)
{
	float3 normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv), _BumpScale);
	float3 tangentSpaceNormal = normal.xzy;
	float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
	
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * i.normal +
		tangentSpaceNormal.z * binormal
	);
	i.normal = normalize(i.normal);
}

fixed4 frag(v2f i) : SV_Target
{
	CalculateFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	//float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

	fixed3 albedo = tex2D(_MainTex,i.uv).xyz*_Tint.xyz;

	half3 specColor;
	half oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(albedo, GetMetallic(i), specColor, oneMinusReflectivity);
	
	float3 shColor = ShadeSH9(float4(i.normal, 1));
	//return float4(shColor, 1);

	float4 color = UNITY_BRDF_PBS(albedo,specColor,
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir, 
		CreateLight(i), CreateIndirectLight(i, viewDir));

	color.rgb += GetEmission(i);
	return color;
}

#endif
