Shader "Custom/Billboard"
{
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Texture Image", 2D) = "white" {}
	}
	SubShader{
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off
		ZTest LEqual
		ZWrite Off

		Tags{ "Queue" = "Transparent+20" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

		Pass{
		CGPROGRAM

		#include "UnityCG.cginc"
		#pragma vertex vert  
		#pragma fragment frag 
        
		uniform sampler2D _MainTex;
		fixed4 _Color;

		struct vertexInput {
			float4 vertex : POSITION;
			float4 uv : TEXCOORD0;
		};
		struct vertexOutput {
			float4 pos : SV_POSITION;
			float4 uv : TEXCOORD0;
		};

		vertexOutput vert(vertexInput input)
		{
			vertexOutput output;

			// get scale
			float scaleX = length(mul(unity_ObjectToWorld, float4(1.0, 0.0, 0.0, 0.0)));
			float scaleY = length(mul(unity_ObjectToWorld, float4(0.0, 1.0, 0.0, 0.0)));

			// new vertex in view space
			float3 center = UnityObjectToViewPos(float3(0.0, 0.0, 0.0));
			float3 vert = center + input.vertex.xyz * float3(scaleX, scaleY, 1);

			// to clip space
			output.pos = mul(UNITY_MATRIX_P, float4(vert, 1.0));
			output.uv = input.uv;
			return output;
		}

		float4 frag(vertexOutput input) : COLOR
		{
			return _Color * tex2D(_MainTex, float2(input.uv.xy));
		}

		ENDCG
		}
	}
}


