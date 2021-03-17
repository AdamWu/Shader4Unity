Shader "Custom/UnityPBS" {
	Properties{
		_Color("Color",Color) = (1,1,1,1)
		_MainTex("MainTex",2D)="white"{}
		_Metallic("Metallic", Range(0,1)) = 0.0
		_Smoothness("Smoothness",Range(0.0,1)) = 0.5
	}
		SubShader{
		Pass{
		CGPROGRAM
		#include "Lighting.cginc"
		#include "UnityCG.cginc"
		#pragma vertex vert
		#pragma fragment frag

		#define PI 3.1415926535

		float4 _Color;
		sampler2D _MainTex;
		float4 _MainTex_ST;
		float _Metallic;
		float _Smoothness;

		struct v2f {
			float4 pos:SV_POSITION;
			float2 uv:TEXCOORD0;
			float3 normal:TEXCOORD1;
			float3 worldPos:TEXCOORD2;
        };

		struct OutPut {
			float3 Albedo;
			float3 normalDir;
			float3 halfDir;
			float Metallic;
			float Smoothness;
			float3 viewDir;
			float3 lightDir;
		};

		//平方
		float sqr(float value) {
			return value * value;
		}

		//微法线分布函数Trowbridge-Reitz GGX
		float D(float roughness, float NdotH) {
			float alpha = sqr(roughness);
			float denominator = sqr(NdotH) * (alpha - 1.0) + 1.0f;
			return alpha / (PI * (sqr(denominator) + 1e-7f));
		}

		//微面元遮挡函数SmithGGX
		float G_smithggx(float roughness, float NdotL, float NdotV) {
			float k = sqr(roughness + 1) / 8;
			//float k = sqr(roughness) / 2;
			float g1 = NdotL / (NdotL * (1 - k) + k); //SchlickGGX
			float g2 = NdotV / (NdotV * (1 - k) + k);
			return g1 * g2;
		}

		//微面元遮挡函数
		float G_smithjoinggx(float roughness,float NdotL,float NdotV) {
#if 0
			float alpha = sqr(roughness);			
			float lambdaV = NdotL * sqrt((-NdotV * alpha + NdotV) * NdotV + alpha);
			float lambdaL = NdotV * sqrt((-NdotL * alpha + NdotL) * NdotL + alpha);
			return 0.5f / (lambdaL + lambdaV + 1e-5f);
#else 
			float alpha = roughness;
			float lambdaV = NdotL * (NdotV * (1 - alpha) + alpha);
			float lambdaL = NdotV * (NdotL * (1 - alpha) + alpha);
			return 0.5f / (lambdaV + lambdaL + 1e-5f);
#endif
		}

		//菲涅尔反射Fresnel Schlick
		float3 F_Term(float3 F0, float VdotH) {
			return F0 + (1 - F0)*pow(1 - VdotH, 5);
		}
		float3 F_Lerp(float3 F0,float3 F90,float VdotH) {
			return lerp(F0, F90, pow(1 - VdotH, 5));
		}

		// Disney漫反射
		float DisneyDiffuse(float NdotL, float NdotV, float LdotH, float roughness) {
			float FD90 = 0.5 + 2 * sqr(LdotH)*roughness;
			float nlPow5 = pow(1 - NdotL, 5);
			float nvPow5 = pow(1 - NdotV, 5);
			float FL = 1 + (FD90 - 1)*pow(1 - NdotL, 5);
			float FV = 1 + (FD90 - 1)*pow(1 - NdotV, 5);
			return FL * FV;
		}

		float4 BRDF(OutPut o, float3 SpecularColor, float oneMinusReflectivity) {
			float roughness = 1 - o.Smoothness;
			float NdotH = saturate(dot(o.normalDir, o.halfDir));
			float LdotH = saturate(dot(o.lightDir, o.halfDir));
			float NdotL = saturate(dot(o.normalDir, o.lightDir));
			float VdotH = saturate(dot(o.viewDir, o.halfDir));
			float NdotV = abs(dot(o.normalDir, o.viewDir));
			
			// diffuse
			float diffuseTerm = DisneyDiffuse(NdotL, NdotV, LdotH, roughness) * NdotL;

			// specular
			roughness = max(roughness, 0.002); // avoid no spec when roughness=0
			float D_1 = D(roughness, NdotH);
			float V = G_smithggx(roughness, NdotL, NdotV);
			float specularTerm = V * D_1 * PI; // Torrance-Sparrow model, Fresnel is applied later
			specularTerm = max(0, specularTerm*NdotL);
			specularTerm *= any(SpecularColor) ? 1.0 : 0.0; // kill specular completely

			//float3 F = F_Term(SpecularColor, LdotH);
			float3 F = F_Term(SpecularColor, VdotH);
			
			// surface reduce(linear space)
			float surfaceReduction = 1.0 / (roughness*roughness + 1.0);
			float grazingTerm = saturate(o.Smoothness + (1 - oneMinusReflectivity));
			float3 Fidentity = F_Lerp(SpecularColor, grazingTerm,VdotH);

			// final color
			float3 color =
				o.Albedo * _LightColor0.rgb * diffuseTerm +
				specularTerm * _LightColor0.rgb * F / (4 * NdotL * NdotV);
			return float4(color, 1);
		}

		float4 LightingStandard(OutPut o) {
			//unity_ColorSpaceDielectricSpec里面存的是Unity选用的电介质反射率，alpha通道是1-dielectricSpec
			float3 specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, o.Albedo, o.Metallic);
			float3 oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a*(1-o.Metallic);
			o.Albedo = o.Albedo * oneMinusReflectivity;
			return BRDF(o, specColor, oneMinusReflectivity);
		}

	    v2f vert(appdata_full v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.normal= UnityObjectToWorldNormal(v.normal);
			o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			return o;
		}

		float4 frag(v2f i) :SV_Target{
			float3 worldNormalDir = normalize(i.normal);
			float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);		
			float3 worldViewDir= normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
			float3 worldHalfDir = normalize(worldLightDir + worldViewDir);

			OutPut o;
			o.Albedo = tex2D(_MainTex, i.uv);
			o.Metallic = _Metallic;
			o.Smoothness = _Smoothness;
			o.normalDir= worldNormalDir;
			o.viewDir = worldViewDir;
			o.lightDir = worldLightDir;
			o.halfDir = worldHalfDir;
			return LightingStandard(o);
		}
		ENDCG
        }	
	}
	FallBack "Diffuse"
}