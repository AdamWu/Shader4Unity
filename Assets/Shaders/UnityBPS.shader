Shader "Custom/UnityPBS" {
	Properties{
		_MainTex("MainTex",2D)="white"{}
	    _Smoothness("Smoothness",Range(0.0,0.9999))=0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
		_SpecularFactor("SpecularFactor",Range(0.0,5.0)) = 1.0
		_DiffuseFactor("DiffuseFactor",Range(0.0,5.0))=0.3
	}
		SubShader{
		Pass{
		CGPROGRAM
		#include "Lighting.cginc"
		#include "UnityCG.cginc"
		#pragma vertex vert
		#pragma fragment frag

		#define PI 3.1415926535

		float _Smoothness;
		sampler2D _MainTex;
		samplerCUBE _Cubemap;
		float _Metallic;
		float _DiffuseFactor;
		float _SpecularFactor;

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
		//微面元遮挡函数
		float G(float roughness,float NdotL,float NdotV) {
			float alpha = sqr(roughness);			
			float lambdaV = NdotL * sqrt((-NdotV * alpha + NdotV) * NdotV + alpha);
			float lambdaL = NdotV * sqrt((-NdotL * alpha + NdotL) * NdotL + alpha);
			return 0.5 / (lambdaL + lambdaV + 0.00001);
		}
		//微法线分布函数
		float D(float roughness,float NdotH){
			float alpha = sqr(roughness);
			float denominator = sqr(NdotH) * (alpha - 1.0) + 1.0f;
			return alpha / (PI * sqr(denominator));
		}
		//菲涅尔反射
		float3 F_Term(float3 F0, float VdotH) {
			return F0 + (1 - F0)*pow(1 - VdotH, 5);
		}
		float3 F_Lerp(float3 F0,float3 F90,float VdotH) {
			return lerp(F0, F90, pow(1 - VdotH, 5));
		}
		//漫反射
		float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness) {
			float FD90 = 0.5 + 2 * sqr(LdotH)*roughness;
			float FL = 1 + (FD90 - 1)*pow(1 - NdotL, 5);
			float FV = 1 + (FD90 - 1)*pow(1 - NdotV, 5);
			return FL * FV*_DiffuseFactor*PI;
		}

		float4 BRDF(OutPut o, float3 SpecularColor, float oneMinusReflectivity) {
			float roughness = 1 - o.Smoothness;
			float NdotH = saturate(dot(o.normalDir, o.halfDir));
			float LdotH = saturate(dot(o.lightDir, o.halfDir));
			float NdotL = saturate(dot(o.normalDir, o.lightDir));
			float VdotH = saturate(dot(o.viewDir, o.halfDir));
			float NdotV = abs(dot(o.normalDir, o.viewDir));
			float diffuseTerm = DisneyDiffuse(NdotV, NdotL, LdotH, roughness)*NdotL;
			float V = G(roughness, NdotL, NdotV);
			float D_1 = D(roughness, NdotH);
			float specularTerm = V * D_1*PI;
			specularTerm = max(0, specularTerm*NdotL);
			float F = F_Term(SpecularColor, LdotH);
			float surfaceReduction = 1.0 / (roughness*roughness + 1.0);
			specularTerm *= any(SpecularColor)?1.0:0.0;
			float grazingTerm = saturate(o.Smoothness + (1 - oneMinusReflectivity));
			float3 Fidentity = F_Lerp(SpecularColor, grazingTerm,VdotH);
			float3 color = o.Albedo*( _LightColor0.rgb*diffuseTerm + 0.5) + specularTerm * _LightColor0.rgb*F*_SpecularFactor + 0.5*surfaceReduction * Fidentity;
			return float4(color, 1);
		}

		float4 LightingStandard(OutPut o) {
			//unity_ColorSpaceDielectricSpec里面存的是Unity选用的电介质反射率，alpha通道是1-dielectricSpec
			float3 specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, o.Albedo, o.Metallic);
			float3 oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a*(1-o.Metallic);
			o.Albedo = o.Albedo*oneMinusReflectivity;
			return BRDF(o, specColor, oneMinusReflectivity);
		}

	    v2f vert(appdata_full v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			o.uv = v.texcoord;
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