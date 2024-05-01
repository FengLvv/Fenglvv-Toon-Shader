Shader "3R2/GF/DEMO/SHADOW_RECEIVER"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        _ShadowColor("Shadow Color", Color) = (1,1,1,1)
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _SHADOWS_SOFT

    // #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    matrix _LighCamtVP;
    TEXTURE2D(_LightCamTexture);
    SAMPLER(sampler_LightCamTexture);
    CBUFFER_START(UnityPerMaterial)
        float4 _ShadowColor;
    CBUFFER_END

    struct Attributes {
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct Varyings {
        float4 positionCS : SV_POSITION;
        float4 posWS : TEXCOORD1;
        float2 uv : TEXCOORD0;
    };

    float calculateLightCamShadow(float3 worldPos)
    {
        float4 posCS = mul(_LighCamtVP, float4(worldPos, 1));
        posCS.xyz /= posCS.w;
        float2 uv = posCS.xy * 0.5 + 0.5;
        float depth = posCS.z;
        float bias = 0.005;
        float textureBias = 1 / 1024.;
        float shadow = depth + bias > SAMPLE_TEXTURE2D(_LightCamTexture, sampler_LightCamTexture, uv).r;
        float shadowL = depth + bias > SAMPLE_TEXTURE2D(_LightCamTexture, sampler_LightCamTexture, uv+float2(-textureBias,textureBias)).r;
        float shadowR = depth + bias > SAMPLE_TEXTURE2D(_LightCamTexture, sampler_LightCamTexture, uv+float2(textureBias,textureBias)).r;
        float shadowT = depth + bias > SAMPLE_TEXTURE2D(_LightCamTexture, sampler_LightCamTexture, uv+float2(-textureBias,-textureBias)).r;
        float shadowB = depth + bias > SAMPLE_TEXTURE2D(_LightCamTexture, sampler_LightCamTexture, uv+float2(textureBias,-textureBias)).r;
        return (shadow * 4 + shadowL + shadowR + shadowT + shadowB) / 8;
    }

    Varyings vert(Attributes IN)
    {
        Varyings OUT;
        VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
        OUT.uv = IN.uv;
        OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
        float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
        OUT.posWS = float4(positionWS, 1);
        //阴影
        return OUT;
    }

    half4 frag(Varyings IN) : SV_Target
    {
        //光照参数
        float shadow = calculateLightCamShadow(IN.posWS.xyz);
        half4 color;
        color.xyz = _ShadowColor.xyz;
        color.w = 1 - shadow;

        //阴影
        return float4(color);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "LightMode"="UniversalForward"
        }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZTest LEqual
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }

    }

}