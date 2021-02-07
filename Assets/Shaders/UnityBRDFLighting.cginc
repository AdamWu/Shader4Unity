#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

struct a2v
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float3 normal:NORMAL;
};

struct v2f
{
	float4 pos : SV_POSITION;
	float3 normal:TEXCOORD1;
	float2 uv : TEXCOORD0;
	float3 worldPos:TEXCOORD2;
#if defined(VERTEXLIGHT_ON)
	float3 vertexLightColor : TEXCOORD3;
#endif
};

sampler2D _MainTex;
float4 _MainTex_ST;
float _Metallic;
float _Smoothness;
fixed3 _DiffuseColor;

v2f vert(a2v v)
{
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = TRANSFORM_TEX(v.uv, _MainTex);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex);
	o.normal = UnityObjectToWorldNormal(v.normal);
#if defined(VERTEXLIGHT_ON)
	o.vertexLightColor = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb,
		unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, o.worldPos, o.normal
	);
	//o.vertexLightColor = unity_LightColor[0].rgb;
#endif
	return o;
}

UnityLight CreateLight(v2f i)
{
	UnityLight light;

#if defined(POINT) || defined(SPOT)
	light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
#else
	light.dir = _WorldSpaceLightPos0.xyz;
#endif
	UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
	light.color = _LightColor0.rgb * attenuation;
	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

UnityIndirect CreateIndirectLight(v2f i) {
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
#endif
	return indirectLight;
}

fixed4 frag(v2f i) : SV_Target
{
	i.normal = normalize(i.normal);
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	//float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

	fixed3 albedo = tex2D(_MainTex,i.uv).xyz*_DiffuseColor.xyz;

	half3 specColor;
	half oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(albedo,_Metallic,specColor,oneMinusReflectivity);
	
	float3 shColor = ShadeSH9(float4(i.normal, 1));
	//return float4(shColor, 1);

	return UNITY_BRDF_PBS(albedo,specColor,oneMinusReflectivity, _Smoothness, i.normal, viewDir, CreateLight(i), CreateIndirectLight(i));
}

#endif
