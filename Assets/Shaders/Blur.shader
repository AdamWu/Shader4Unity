Shader "Test/Blur"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
	
	SubShader
	{
		Cull Off ZWrite Off ZTest Always 

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 coord : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;

				float4 uv01 : TEXCOORD1;
				float4 uv23 : TEXCOORD2;
				float4 uv45 : TEXCOORD3;
			};

			float4 offsets;
			sampler2D _MainTex;
			float4 _MainTex_TexelSize;

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.coord;

				o.uv01 = v.coord.xyxy + _MainTex_TexelSize.xyxy * offsets.xyxy * float4(1, 1, -1, -1);
				o.uv23 = v.coord.xyxy + _MainTex_TexelSize.xyxy * offsets.xyxy * float4(1, 1, -1, -1) * 2;
				o.uv45 = v.coord.xyxy + _MainTex_TexelSize.xyxy * offsets.xyxy * float4(1, 1, -1, -1) * 3;

				return o;
			}


			half4 frag(v2f i) : SV_Target
			{
				half4 col = float4(0,0,0,0);
				col += 0.40 * tex2D(_MainTex, i.uv);
				col += 0.15 * tex2D(_MainTex, i.uv01.xy);
				col += 0.15 * tex2D(_MainTex, i.uv01.zw);
				col += 0.10 * tex2D(_MainTex, i.uv23.xy);
				col += 0.10 * tex2D(_MainTex, i.uv23.zw);
				col += 0.05 * tex2D(_MainTex, i.uv45.xy);
				col += 0.05 * tex2D(_MainTex, i.uv45.zw);

				return col;
			}
			ENDCG
		}
	}
}
