Shader "Unlit/GF"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset][Normal] _Normal ("Normal", 2D) = "white" {}
        [NoScaleOffset]_HairSpecularMap ("HairSpecularMap", 2D) = "white" {}
        [NoScaleOffset]_FaceSDFMap ("FaceSDFMap", 2D) = "white" {}
        [NoScaleOffset]_RMO ("RMO", 2D) = "white" {}
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}
        [NoScaleOffset]_Ramp2 ("RampMetal", 2D) = "white" {}
        _Skybox ("Skybox", Cube) = "white" {}

        //控制效果
        [Header(ColorAdjust)]
        _ColorAdjust ("ColorAdjust", Range(0,1)) = 1
        [Header(Lambert)]
        _DichotomyThreshold ("DichotomyThreshold", Range(0,1)) = 0.5
        _DichotomyRange ("DichotomyRange", Range(0,0.05)) = 0.02
        _ShadowDarkness ("ShadowDarkness", Range(0,1)) = 0.5
        _ShadowColor ("ShadowColor", Color) = (1,1,1,1)
        _GradiantSaturation ("GradiantSaturation", Range(0,2)) = 0.5
        [HDR] _GradiantColor ("RGB:GradiantColor,W:merge", Color) = (1,1,1,1)
        _EnvDif("EnvDif", Range(0,1)) = 0.5
        _EnvSpec("EnvSpec", Range(0,1)) = 0.5



        [Header(PBR)]
        _PBRMergeRatio ("总PBR混入量", Range(0,1)) = 0.5
        _PBREven ("PBR混入均匀度", Range(0,1)) = 0.5
        _AOIntensity ("AOIntensity", Range(0,1)) = 0.5

        [Header(Hair)]
        _FringeShadowColor ("FringeShadowColor", Color) = (0,0,0,1)
        _FringeShadowWidth ("FringeShadowWidth", Range(0,1)) = 0.5

        [Header(Specular)]
        _GlossyExp ("GlossyExp", Range(0,50)) = 10
        _SpecularIntensity ("SpecularIntensity", Range(0,10)) = 1
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)

        [Header(RimLight)]
        _Rim ("Rim", Range(0,0.5)) = 0.5
        _RimColor ("RimColor", Color) = (1,1,1,1)
        _RimIntensity ("RimIntensity", Range(0,10)) = 1
        _ShadowRim ("ShadowRim", Range(0,1)) = 0.5

        [Header(Details)]
        _InnerLine ("InnerLine", Range(0,1)) = 0.5
        _HonmuraLine ("HonmuraLine", Range(0,1)) = 0.5

        [Header(Outline)]
        _OutlineWidth ("OutlineWidth", Range(0,0.01)) = 0.01
        _MaxOutline ("MaxOutline", Range(0,1)) = 0.05
        [Toggle]_CHANGEOUTLINE("CHANGEOUTLINE", int) = 1

        [Header(Shader Features)]
        [KeywordEnum(Hair,Face,Body,Cloth,Eye)]_Part("渲染部位", int) = 0
        //stecil     
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp("Stencil Operation", Float) = 0
        //写入值
        _StencilWriteValue("写入值", Float) = 0
    }

    HLSLINCLUDE
    #include "./GFInclude.hlsl"
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma shader_feature _ _PART_HAIR _PART_FACE _PART_BODY _PART_CLOTH _PART_EYE
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
            stencil
            {
                Ref [_StencilWriteValue] //为当前片元设置参考值（0-255），与缓冲区的值比较          
                Comp Always //比较操作
                Pass [_StencilOp] //模板测试通过后的操作    
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
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