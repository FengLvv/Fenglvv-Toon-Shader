Shader "3R2/GF/HAIR/FRONT"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset]_HairSpecularMap ("头发高光", 2D) = "white" {}
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}
        _Skybox ("Skybox", Cube) = "white" {}

        //控制效果
        [Header(ColorAdjust)]
        _ColorAdjust ("逆toneMapping", Range(0,1)) = 1

        [header(Hair)]
        _FringeShadowWidth ("刘海位移", Range(0,1)) = 0.5
        _FringeShadowColor ("刘海颜色", Color) = (1,1,1,1)


        [Header(Lambert)]
        _DichotomyThreshold ("二分线", Range(0,1)) = 0.5
        _DichotomyRange ("二分渐变范围", Range(0,0.05)) = 0.02
        _ShadowDarkness ("阴影明度", Range(0,1)) = 0.5
        _ShadowColor ("阴影颜色", Color) = (1,1,1,1)
        _GradiantSaturation ("渐变纯度", Range(0,2)) = 0.5
       [HDR] _GradiantColor ("RGB:渐变颜色,W:混合渐变", Color) = (1,1,1,1)
        _EnvDif("环境漫射强度", Range(0,1)) = 0.5
        _EnvSpec("环境高光强度", Range(0,1)) = 0.5

        [Header(PBR)]
        _Roughness ("粗糙度", Range(0,1)) = 1
        _Metallic("金属度", Range(0,1)) = 0
        _DisneyDiffuseMergeRatio ("pbr漫反射混入量", Range(0,1)) = 0.5

        [Header(Specular)]
        _SpecularIntensity ("高光强度", Range(0,10)) = 1
        _SpecularColor ("高光颜色", Color) = (1,1,1,1)

        [Header(Outline)]
        _MaxOutline ("MaxOutline", Range(0,1)) = 0.05

        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5

        [Header(Write stencil)]
        _StencilWriteFringe("刘海模板写入值", Float) = 0
        _StencilReadShadow("刘海投影模板比较值（面部模板写入值)", Float) = 0


    }

    HLSLINCLUDE
    #include "./GFBasic.hlsl"
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma shader_feature _ _PART_HAIR _PART_FACE _PART_BODY _PART_CLOTH _PART_EYE
    #pragma shader_feature_local _HAIR_FRONT
    ENDHLSL
    SubShader
    {
        Pass
        {
            Stencil
            {
                Ref [_StencilWriteFringe]
                Comp Always
                Pass Replace
            }
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
        Pass
        {

            Name "Fringe"
            Tags
            {
                "LightMode"="Fringe"
                "Queue"="Geometry+1"
                "RenderType"="Opaque"
            }
            stencil
            {
                Ref [_StencilReadShadow] //为当前片元设置参考值（0-255），与缓冲区的值比较          
                Comp Equal //比较操作          
            }
            ZTest LEqual
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex fringe_vert
            #pragma fragment fringe_frag
            ENDHLSL
        }
    }
}