// Upgrade NOTE: upgraded instancing buffer 'Props' to new syntax.

Shader "Unlit/CameraFilterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

		_ObjectColor("Object Color", Color) = (1,1,1,1)
		_CategoryColor("Catergory Color", Color) = (0,1,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
			#pragma multi_compile_instancing

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

			struct appdata 
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

            struct v2f
            {
				float4 pos : SV_POSITION;
				float4 nz : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			int _FilterType;

			UNITY_INSTANCING_BUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP(fixed4, _ObjectColor)
			UNITY_DEFINE_INSTANCED_PROP(fixed4, _CategoryColor)
			UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v)
            {
                v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.pos = UnityObjectToClipPos(v.vertex);
				o.nz.xyz = COMPUTE_VIEW_NORMAL;
				o.nz.w = COMPUTE_DEPTH_01;
                return o;
            }

			half4 frag(v2f i) : SV_Target
            {
				UNITY_SETUP_INSTANCE_ID(i);

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
				else if (_FilterType == 3) 
				{
					// [-1, 1] => [0, 1]
					return half4(i.nz.xyz * 0.5 + 0.5, 1);
				}
				else if (_FilterType == 4) 
				{
					return UNITY_ACCESS_INSTANCED_PROP(Props, _ObjectColor);
				}
				else {
					return half4(0,0,0,1);
				} 
            }
            ENDCG
        }
    }
}
