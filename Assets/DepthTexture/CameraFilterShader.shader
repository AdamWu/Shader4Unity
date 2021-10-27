Shader "Unlit/CameraFilterShader"
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

            #include "UnityCG.cginc"

			// remap depth: [0 @ eye .. 1 @ far] => [0 @ near .. 1 @ far]
			inline float Linear01FromEyeToLinear01FromNear(float depth01)
			{
				float near = _ProjectionParams.y;
				float far = _ProjectionParams.z;
				return (depth01 - near / far) * (1 + near / far);
			}

            struct v2f
            {
				float4 pos : SV_POSITION;
				float4 nz : TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			int _FilterType;

            v2f vert (appdata_base v)
            {
                v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
				o.nz.xyz = COMPUTE_VIEW_NORMAL;
				o.nz.w = COMPUTE_DEPTH_01;
                return o;
            }

			half4 frag(v2f i) : SV_Target
            {
				if (_FilterType == 1) {
					float depth = i.nz.w;
					return half4(depth, depth, depth, 1);
				}
				else if (_FilterType == 2)
				{
					float depth = i.nz.w;
					depth = Linear01FromEyeToLinear01FromNear(depth);
					depth = pow(depth, 0.25);
					return half4(depth, depth, depth, 1);
				}
				else if (_FilterType == 3) {

					// [-1, 1] => [0, 1]
					return half4(i.nz.xyz * 0.5 + 0.5, 1);
				}
				else {
					return half4(0,0,0,1);
				}
            }
            ENDCG
        }
    }
}
