Shader "3R2/GF/INLINE"
{
    Properties
    {
        [Toggle] _AdditionalLight ("Add light", Float) = 0
    }

    HLSLINCLUDE
    #include "./GFBasic.hlsl"
    //额外光照
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    //lightmap
    #pragma multi_compile _ LIGHTMAP_ON
    ENDHLSL
    SubShader
    {
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Name "Inline"
            Tags
            {
                "LightMode"="Inline"
            }
            ZWrite Off
            ZTest Equal
            HLSLPROGRAM
            #pragma vertex inline_vert
            #pragma fragment inline_frag
            ENDHLSL
        }
    }
}