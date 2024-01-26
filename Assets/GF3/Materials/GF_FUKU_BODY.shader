Shader "3R2/GF/FUKU_BODY"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset][Normal] _Normal ("Normal", 2D) = "white" {}
        [NoScaleOffset]_RMO ("RMO", 2D) = "white" {}
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}
        _Skybox ("Skybox", Cube) = "white" {}

        //控制效果
        [Header(ColorAdjust)]
        _ColorAdjust ("逆toneMapping", Range(0,1)) = 1
        
        [Header(Lambert)]
        _DichotomyThreshold ("二分线", Range(0,1)) = 0.5
        _DichotomyRange ("二分渐变范围", Range(0,0.05)) = 0.02
        _ShadowDarkness ("阴影明度", Range(0,1)) = 0.5
        _ShadowColor ("阴影颜色", Color) = (1,1,1,1)
        _GradiantSaturation ("渐变纯度", Range(0,2)) = 0.5
         [HDR]_GradiantColor ("RGB:渐变颜色,W:混合渐变", Color) = (1,1,1,1)
        _EnvDif("环境漫射强度", Range(0,1)) = 0.5
        _EnvSpec("环境高光强度", Range(0,1)) = 0.5

        [Header(PBR)]
        _DisneyDiffuseMergeRatio ("pbr漫反射混入量", Range(0,1)) = 0.5
        _AOIntensity ("AO强度", Range(0,1)) = 0.5

        [Header(Specular)]
        _SpecularIntensity ("高光强度", Range(0,10)) = 1
        _SpecularColor ("高光颜色", Color) = (1,1,1,1)

        [Header(Outline)]
        _MaxOutline ("MaxOutline", Range(0,1)) = 0.05
                      
        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5
    }

    HLSLINCLUDE
    #include "./GFBasic.hlsl"
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma shader_feature _PBR
    ENDHLSL
    SubShader
    {
        Pass
        {
            Tags
            {
                "RenderType"="Opaque"
                "Queue"="Geometry"
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
       
    }
}