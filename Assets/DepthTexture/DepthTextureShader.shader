Shader "Unlit/DepthTextureShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
				float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
				float4 screenUV : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			sampler2D _CameraDepthTexture;
			sampler2D _CameraDepthNormalsTexture;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
				o.screenUV = ComputeScreenPos(o.vertex);
                return o;
            }

			fixed4 getDepth(float4 uv) {

				//float2 uv = uv.xy / uv.w;
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv).r;
				depth = Linear01Depth(depth);

				// equal to this
				depth = Linear01Depth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(uv)).r);

				return fixed4(depth, depth, depth, 1.0);
			}

			fixed4 getNormal(float4 uv) {
				fixed3 normal = DecodeViewNormalStereo(tex2D(_CameraDepthNormalsTexture, uv));
				return fixed4(normal, 1.0);
			}

			fixed4 frag(v2f i) : SV_Target
            {
                return getDepth(i.screenUV);
				//return getNormal(i.screenUV);
            }

            ENDCG
        }
    }
}
