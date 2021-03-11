Shader "Hidden/Custom Pipeline/PostEffectStack" {
	SubShader {

		Cull Off
		ZTest Always
		ZWrite Off

		Pass {
			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex DefaultPassVertex
			#pragma fragment CopyPassFragment
			#include "../ShaderLibrary/PostEffectStack.hlsl"
			ENDHLSL
		}

		Pass { // blur
			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex DefaultPassVertex
			#pragma fragment BlurPassFragment
			#include "../ShaderLibrary/PostEffectStack.hlsl"
			ENDHLSL
		}


		Pass { // depth strips
			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex DefaultPassVertex
			#pragma fragment DepthStripsPassFragment
			#include "../ShaderLibrary/PostEffectStack.hlsl"
			ENDHLSL
		}
	}
}