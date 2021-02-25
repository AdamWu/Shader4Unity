Shader "Hidden/FXAA" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex;
		float4 _MainTex_TexelSize;
		float _ContrastThreshold;
		float _RelativeThreshold;
		float _SubpixelBlending;

		struct VertexData {
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct Interpolators {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

		Interpolators VertexProgram (VertexData v) {
			Interpolators i;
			i.pos = UnityObjectToClipPos(v.vertex);
			i.uv = v.uv;
			return i;
		}


		float4 Sample(float2 uv) {
			return tex2Dlod(_MainTex, float4(uv, 0, 0));
		}

		float SampleLuminance(float2 uv) {
			#if defined(LUMINANCE_GREEN)
				return Sample(uv).g;
			#else
				return Sample(uv).a;
			#endif
		}

		float SampleLuminance(float2 uv, float uOffset, float vOffset) {
			uv += _MainTex_TexelSize * float2(uOffset, vOffset);
			return SampleLuminance(uv);
		}

		struct LuminanceData {
			float m, n, e, s, w;
			float ne, nw, se, sw;
			float highest, lowest, contrast;
		};

		LuminanceData SampleLuminanceNeighborhood(float2 uv) {
			LuminanceData l;
			l.m = SampleLuminance(uv);
			l.n = SampleLuminance(uv, 0, 1);
			l.e = SampleLuminance(uv, 1, 0);
			l.s = SampleLuminance(uv, 0, -1);
			l.w = SampleLuminance(uv, -1, 0);
			l.ne = SampleLuminance(uv, 1, 1);
			l.nw = SampleLuminance(uv, -1, 1);
			l.se = SampleLuminance(uv, 1, -1);
			l.sw = SampleLuminance(uv, -1, -1);
			l.highest = max(max(max(max(l.n, l.e), l.s), l.w), l.m);
			l.lowest = min(min(min(min(l.n, l.e), l.s), l.w), l.m);
			l.contrast = l.highest - l.lowest;
			return l;
		}

		bool ShouldSkipPixel(LuminanceData l) {
			float threshold = max(_ContrastThreshold, _RelativeThreshold * l.highest);
			return l.contrast < threshold;
		}

		float DeterminePixelBlendFactor(LuminanceData l) {
			float filter = 2 * (l.n + l.e + l.s + l.w);
			filter += l.ne + l.nw + l.se + l.sw;
			filter *= 1.0 / 12;
			filter = abs(filter - l.m);
			filter = saturate(filter / l.contrast);
			float blendFactor = smoothstep(0, 1, filter);
			return blendFactor * blendFactor * _SubpixelBlending;
		}
		struct EdgeData {
			bool isHorizontal;
			float pixelStep;
		};

		EdgeData DetermineEdge(LuminanceData l) {
			EdgeData e;
			float horizontal =
				abs(l.n + l.s - 2 * l.m) * 2 +
				abs(l.ne + l.se - 2 * l.e) +
				abs(l.nw + l.sw - 2 * l.w);
			float vertical =
				abs(l.e + l.w - 2 * l.m) * 2 +
				abs(l.ne + l.nw - 2 * l.n) +
				abs(l.se + l.sw - 2 * l.s);
			e.isHorizontal = horizontal >= vertical;
			float pLuminance = e.isHorizontal ? l.n : l.e;
			float nLuminance = e.isHorizontal ? l.s : l.w;
			float pGradient = abs(pLuminance - l.m);
			float nGradient = abs(nLuminance - l.m);
			e.pixelStep = e.isHorizontal ? _MainTex_TexelSize.y : _MainTex_TexelSize.x;
			if (pGradient < nGradient) e.pixelStep = -e.pixelStep;
			return e;
		}

		float4 ApplyFXAA(float2 uv) {
			LuminanceData l = SampleLuminanceNeighborhood(uv);
			if (ShouldSkipPixel(l)) {
				return Sample(uv);
			}
			float pixelBlend = DeterminePixelBlendFactor(l);
			EdgeData e = DetermineEdge(l);
			
			if (e.isHorizontal) {
				uv.y += e.pixelStep * pixelBlend;
			}
			else {
				uv.x += e.pixelStep * pixelBlend;
			}
			return float4(Sample(uv).rgb, l.m);
		}
	ENDCG

	SubShader {
		Cull Off
		ZTest Always
		ZWrite Off

		Pass { // 0 LuminancePass
			CGPROGRAM
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			float4 FragmentProgram (Interpolators i) : SV_Target {
				float4 sample = tex2D(_MainTex, i.uv);
				sample.a = LinearRgbToLuminance(saturate(sample.rgb));
				return sample;
			}
			ENDCG
		}
		Pass { // 1 fxaaPass
			CGPROGRAM
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			#pragma multi_compile _ LUMINANCE_GREEN

			float4 FragmentProgram(Interpolators i) : SV_Target {
				return ApplyFXAA(i.uv);
			}
			ENDCG
		}
	}
}