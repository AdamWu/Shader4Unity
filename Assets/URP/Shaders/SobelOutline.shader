Shader "Custom Pipeline/Sobel Outline" 
{
	Properties 
	{
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_Outline ("Width", Range (0, 5)) = 1
		_Strength("Strength", Range(0, 1)) = 1
	}
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		
		Pass 
		{
			Name "OUTLINE"
			
			Stencil {
				Ref 1
				Comp equal
			}

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
            CBUFFER_START(UnityPerMaterial)
            float _Outline;
            float4 _OutlineColor;
			float _Strength;
            CBUFFER_END

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);

			TEXTURE2D(_CameraDepthTexture);
			SAMPLER(sampler_CameraDepthTexture);
			float4 _CameraDepthTexture_TexelSize;

            struct Attributes 
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
				float2 uv : TEXCOORD0;
            };
        
            struct Varyings 
            {
                float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float2 uvs[9] : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
			float SampleDepth(float2 uv)
			{
#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				return SAMPLE_TEXTURE2D_ARRAY(_CameraDepthTexture, sampler_CameraDepthTexture, uv, unity_StereoEyeIndex).r;
#else
				return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
#endif
			}

            Varyings vert(Attributes input) 
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
				output.uv = input.uv;

				output.uvs[0] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(-1, -1) * _Outline;
				output.uvs[1] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(0, -1) * _Outline;
				output.uvs[2] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(1, -1) * _Outline;
				output.uvs[3] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(-1, 0) * _Outline;
				output.uvs[4] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(0, 0) * _Outline;
				output.uvs[5] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(1, 0) * _Outline;
				output.uvs[6] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(-1, 1) * _Outline;
				output.uvs[7] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(0, 1) * _Outline;
				output.uvs[8] = input.uv + _CameraDepthTexture_TexelSize.xy * half2(1, 1) * _Outline;

                return output;
            }
			
			half4 frag(Varyings input) : SV_Target
			{
				const half Gx[9] = {
					-1,  0,  1,
					-2,  0,  2,
					-1,  0,  1
				};

				const half Gy[9] = {
					-1, -2, -1,
					0,  0,  0,
					1,  2,  1
				};

				float edgeY = 0;
				float edgeX = 0;
				for (int i = 0; i < 9; i++ )
				{
					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uvs[i]);
					depth = LinearEyeDepth(depth, _ZBufferParams);
					edgeX += depth * Gx[i];
					edgeY += depth * Gy[i];
				}
				float edge = (1 - abs(edgeX) - abs(edgeY));
				edge = saturate(edge);
				//return float4(edge.xxx, 1);

				half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
				return lerp(color * (1-_Strength), color, edge);
			}
            ENDHLSL
		}
	}
}
