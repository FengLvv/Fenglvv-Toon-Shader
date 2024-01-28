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

    CBUFFER_START(UnityPerMaterial)
        float4 _ShadowColor;
    CBUFFER_END

    struct Attributes {
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct Varyings {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
          float4 shadowCoord : TEXCOORD4;
    };

    Varyings vert(Attributes IN)
    {
        Varyings OUT;
        VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
        OUT.uv = IN.uv;
        OUT. positionCS = TransformObjectToHClip(IN.positionOS.xyz);
         float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
        //阴影
        OUT.shadowCoord = TransformWorldToShadowCoord(positionWS);
        return OUT;
    }

    half4 frag(Varyings IN) : SV_Target
    {
        //光照参数
        Light mainLight = GetMainLight(IN.shadowCoord);
        float lightAttenuation = mainLight.shadowAttenuation;

        half4 color;
        // color.xyz = _ShadowColor.xyz;
        color.xyz = _ShadowColor.xyz ;
        color.w = 1- lightAttenuation;

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