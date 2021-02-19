Shader "Custom/Deferred Fog" 
{
	Properties
	{
		_MainTex("Source", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off
		ZTest Always
		ZWrite Off

		Pass {
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fog

			#define FOG_DISTANCE

			#include "UnityCG.cginc"

			sampler2D _MainTex, _CameraDepthTexture;
			float3 _FrustumCorners[4];

			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
#if defined(FOG_DISTANCE)
				float3 ray : TEXCOORD1;
#endif
			};


			v2f vert(a2v i)
			{
				v2f o; 
				o.pos = UnityObjectToClipPos(i.vertex);
				o.uv = i.uv; 
#if defined(FOG_DISTANCE)
				o.ray = _FrustumCorners[o.uv.x + 2 * o.uv.y];
#endif
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth = Linear01Depth(depth);
				float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
#if defined(FOG_DISTANCE)
				viewDistance = length(i.ray * depth);
#endif
				UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
				unityFogFactor = saturate(unityFogFactor);
				// ignore skybox
				if (depth > 0.9999) unityFogFactor = 1;
				// fog disabled
#if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
				unityFogFactor = 1;
#endif

				float3 color = tex2D(_MainTex, i.uv).rgb;
				color = lerp(unity_FogColor.rgb, color, unityFogFactor);
				return float4(color, 1);
			}

			ENDCG
		}
	}
}