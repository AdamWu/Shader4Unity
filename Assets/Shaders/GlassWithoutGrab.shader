Shader "Test/GlassWithoutGrab"
{
	Properties 
	{
		_MainTex("Tint (RGB)", 2D) = "white"{}
		_MainTexAmount("Tint Amount", Range(0, 1)) = 0.2
		_BumpMap("Normal Map", 2D) = "bump"{}
	}
	
	SubShader 
	{
		Tags {"RenderType"="Opaque" "Queue"="Transparent"}
		LOD 100
		
		Pass 
		{
			Name "BASE"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};
			
			struct v2f 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 uvgrab :TEXCOORD1;
			};
			
			sampler2D _GrabBlurTexture;
			float4 _GrabBlurTexture_TexelSize;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _MainTexAmount;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
#else
				float scale = 1.0;
#endif
				o.uvgrab.xy = (float2(o.pos.x, o.pos.y*scale) + o.pos.w) * 0.5;
				o.uvgrab.zw = o.pos.zw;
				return o;
			}
			
			half4 frag(v2f i) : SV_Target
			{
				half4 col = tex2D(_MainTex, i.uv);
				//half4 grab = tex2Dproj(_GrabBlurTexture, UNITY_PROJ_COORD(i.uvgrab));
				half4 grab = tex2Dproj(_GrabBlurTexture, i.uvgrab);

				col = lerp(col, grab, _MainTexAmount);

				return col;
			}
			
			ENDCG
		}
	}

	FallBack "Diffuse"
}