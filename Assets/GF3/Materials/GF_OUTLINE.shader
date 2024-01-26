Shader "3R2/GF/OUTLINE"
{
    HLSLINCLUDE
    #include "./GFBasic.hlsl"
    ENDHLSL
    SubShader
    {      
        Pass
        {
            Name "Outline"
            Tags
            {
                "LightMode"="Outline"
            }
            Cull Front
            ZWrite Off
            ZTest Less
            HLSLPROGRAM            
            #pragma vertex outline_vert
            #pragma fragment outline_frag            
            ENDHLSL
        }
    }
}