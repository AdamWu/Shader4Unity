Shader "Custom/UnityBRDF"
{
	Properties
	{
		_Metallic("_Metallic",Range(0,1)) = 0
		_DiffuseColor("DiffuseColor",Color) = (1,1,1,1)
		_MainTex("Texture", 2D) = "white" {}
		_Smoothness("Smoothness",Range(0,1)) = 0
	}
		SubShader
		{
			Pass
			{
				Tags{"LightMode" = "ForwardBase"}

				CGPROGRAM
				#pragma target 3.0
				#pragma vertex vert
				#pragma fragment frag

				#include"UnityStandardUtils.cginc"
				#include"AutoLight.cginc"
				#include "UnityCG.cginc"
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
					o.worldPos = mul(unity_ObjectToWorld,v.vertex);
					o.normal = UnityObjectToWorldNormal(v.normal);
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{
					//data
					float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
					float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
					float3 worldNormal = normalize(i.normal);

					fixed3 albedo = tex2D(_MainTex,i.uv).xyz*_DiffuseColor.xyz;

					half3 specColor;
					half oneMinusReflectivity;
					albedo = DiffuseAndSpecularFromMetallic(albedo,_Metallic,specColor,oneMinusReflectivity);

					UnityLight DirectLight;
					DirectLight.dir = worldLightDir;
					DirectLight.color = _LightColor0.xyz;
					DirectLight.ndotl = DotClamped(worldNormal,worldLightDir);

					UnityIndirect InDirectLight;
					InDirectLight.diffuse = 0;
					InDirectLight.specular = 0;

					return UNITY_BRDF_PBS(albedo,specColor,oneMinusReflectivity,
																_Smoothness,worldNormal,worldViewDir,
																DirectLight,InDirectLight);
				}
				ENDCG
			}
		}
}
