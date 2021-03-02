Shader "Custom Pipeline/Unlit"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        
		Pass{

			HLSLPROGRAM
			#pragma target 3.5

			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			#include "../ShaderLibrary/Unlit.hlsl" 

			ENDHLSL
		}
    }
}
