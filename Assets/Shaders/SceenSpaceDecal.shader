Shader "SmartEditor/SceenSpaceDecal"
{
	Properties
	{
		_MainTex ("Decal Texture", 2D) = "white" {}
		_Color("Color", color) = (1,1,1,1)
	}

	SubShader
	{
		Tags{ "RenderType" = "Overlay" "Queue" = "AlphaTest+1" }

		Pass
		{
			// useful if camera goes into cube volume
			Cull Front
			ZTest Always

			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 screenUV : TEXCOORD0;
				float3 ray : TEXCOORD1;
			};
			
			v2f vert (appdata_base v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.screenUV = ComputeScreenPos (o.pos);
				o.ray = UnityObjectToViewPos(v.vertex).xyz * float3(-1, -1, 1);
				return o;
			}

			sampler2D _MainTex;
			half4 _Color;
			sampler2D _CameraDepthTexture;

			float4 frag(v2f i) : SV_Target
			{
				float2 uv = i.screenUV.xy / i.screenUV.w;
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				depth = Linear01Depth (depth) * 1;

				//return float4(i.ray.z, i.ray.z, i.ray.z, 1);

				float3 rayToFarPlane = i.ray * (_ProjectionParams.z / i.ray.z);
				float3 vpos = rayToFarPlane * depth;
				float3 wpos = mul (unity_CameraToWorld, float4(vpos,1)).xyz;
				float3 opos = mul (unity_WorldToObject, float4(wpos,1)).xyz;
				//clip (float3(0.5,0.5,0.5) - abs(opos.xyz));

				return float4(rayToFarPlane, 1);

				// 转换到 [0,1] 区间
				float2 texUV = opos.xz + 0.5;

				float4 col = tex2D (_MainTex, texUV);
				col *= _Color;
				return col;
			}
			ENDCG
		}
	}

	Fallback Off
}