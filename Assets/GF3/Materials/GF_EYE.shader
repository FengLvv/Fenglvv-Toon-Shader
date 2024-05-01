Shader "3R2/GF/EYE"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [MainTexture] [NoScaleOffset] _FaceSDFMap ("FaceSDFMap", 2D) = "white" {}

        [Header(Eye)]
        _EyeScale ("EyeScale", Float) = 50
        _EyeDepth ("EyeDepth", Float) = 1
        _Refraction ("Refraction", Float) = 0.4

        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend ("SrcBlend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend ("DstBlend", Float) = 0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    //贴图
    TEXTURE2D(_BaseMap);
    SAMPLER(sampler_BaseMap);
    TEXTURE2D(_FaceSDFMap);
    SAMPLER(sampler_FaceSDFMap);
    float3 _eyePos;
    float3 _eyeDir;

    CBUFFER_START(UnityPerMaterial)
        float _EyeScale;
        float _EyeDepth;
        float _Refraction;
    CBUFFER_END

    #include "TOONFUNCTIONS.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "Assets/MyMaterial/Repo/PBR.hlsl"
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"

    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma shader_feature_local _FACE

    #define vAdditionalLightRamp  0.8
    #define vMetalEnvSpecRamp  0.55
    #define vLightSpecRamp  0.3
    #define vDirectLightMapRamp 0.05

    CBUFFER_START(UnityPerMaterial)
        float _FrontLight;
        float _ShadowDarkness;

        float _DisneyDiffuseMergeRatio;

        float _LightColorEffect;

        float _EnvDif;

        float _Roughness;
        float _Metallic;
    CBUFFER_END

    struct Attributes {
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
        float2 uv2 : TEXCOORD1;
        float4 color : COLOR;
        float3 normalOS : NORMAL;
        float4 tangent : TANGENT;
    };

    struct Varyings {
        float4 color : COLOR;
        float2 uv : TEXCOORD0;
        float2 uv2 : TEXCOORD1;
        float4 positionHCS : SV_POSITION;
        float3 positionWS : TEXCOORD2;
        float3 normalWS : NORMAL;
        float3 tangentWS : TANGENT;
        float3 bitangentWS : BINORMAL;
        float4 shadowCoord : TEXCOORD4;
    };

    Varyings vertFace(Attributes IN)
    {
        Varyings OUT;
        VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
        OUT.uv = IN.uv;
        OUT.uv2 = IN.uv2;
        OUT.positionHCS = vertices.positionCS;
        OUT.positionWS = vertices.positionWS;
        OUT.color = IN.color;
        OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
        OUT.tangentWS = TransformObjectToWorldDir(IN.tangent.xyz);
        OUT.bitangentWS = cross(OUT.normalWS, OUT.tangentWS) * IN.tangent.w;
        //阴影
        OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS.xyz);
        return OUT;
    }

    half4 fragFace(Varyings IN) : SV_Target
    {
        half4 OUT = 1;

        //////////////////////////////////////////
        //////////////////参数准备/////////////////
        /////////////////////////////////////////    
        //光照参数
        Light mainLight = GetMainLight();
        float3 lightDirWS = normalize(mainLight.direction);
        float3 lightColor = mainLight.color;
        lightColor *= _LightColorEffect;

        //相机参数
        float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS.xyz);
        //角色方向
        float3 forwardWS = TransformObjectToWorldDir(float3(0, 0, 1));
        float3 leftWS = TransformObjectToWorldDir(float3(1, 0, 0));
        float3 normalWS = IN.normalWS;

        /////////////////////////////////////////
        ///////////////////NPR///////////////////
        /////////////////////////////////////////
        //面部SDF
        float faceShadow = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, IN.uv2, lightDirWS, normalWS, forwardWS, leftWS).x;


        float3 viewLS = TransformWorldToObjectDir(viewDirectionWS);
        float2 uv = IN.uv - viewLS.xy * 0.3;

        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv.xy);
        OUT = baseColor;
        // if (camRefractPosES.x < 0 || camRefractPosES.x > 1 || camRefractPosES.y < 0 || camRefractPosES.y > 1)
        // {
        //     OUT.a = 0;
        // }

        float3 diffuseCol = lerp(baseColor.rgb * 0.3, baseColor, faceShadow);

        //////////////////////////////////////////
        //////////////////多光源///////////////////
        //////////////////////////////////////////
        //获取其他光源详细
        float3 otherLightColor = 0;
        float otherLightAttenuation = 0;
        uint lightsCount = GetAdditionalLightsCount(); //获取灯光总数
        for (uint lightIndex = 0u; lightIndex < lightsCount; ++lightIndex)
        {
            //用来循环，得到index
            Light addLight = GetAdditionalLight(lightIndex, IN.positionWS); //输入index，获取光照
            half3 eachLightColor = addLight.color * addLight.distanceAttenuation;

            float3 halfVecWS = normalize(viewDirectionWS + addLight.direction);
            float blinnPhone = mul(halfVecWS, normalWS);
            blinnPhone *= blinnPhone * blinnPhone * blinnPhone * blinnPhone * blinnPhone;
            blinnPhone *= blinnPhone * blinnPhone;

            #ifndef _FACE
            otherLightColor += blinnPhone * eachLightColor;
            otherLightAttenuation += blinnPhone;
            #else
        otherLightColor+=eachLightColor*0.01;
            #endif
        }
        float3 color = otherLightColor + diffuseCol;

        clip(OUT.a - 0.01);
        return OUT;
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="TransparentCutout"
            "Queue"="AlphaTest"
            "LightMode"="UniversalForward"
        }
        Pass
        {
            ZTest LEqual
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex vertFace
            #pragma fragment fragFace
            ENDHLSL
        }
    }
}