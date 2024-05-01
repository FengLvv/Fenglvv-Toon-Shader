Shader "3R2/GF/BROW"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset]_FaceSDFMap ("FaceSDFMap", 2D) = "white" {}
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}

        [Header(Lambert)]
        _ShadowDarkness ("阴影明度", Range(0,1)) = 0.5

        _EnvDif("环境漫射强度", Range(0,10)) = 0.5
        _LightColorEffect("主光照颜色影响", Range(0,2)) = 1

        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5

        [Header(Write stencil and ztest)]
        _StencilCompareValue("参考值", Float) = 0

        [HideInInspector]//support shadow
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [HideInInspector]//support shadow
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Clipping", Float) = 0

    }

    HLSLINCLUDE
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

    TEXTURE2D(_BaseMap);
    SAMPLER(sampler_BaseMap);


    TEXTURE2D(_FaceSDFMap);
    SAMPLER(sampler_FaceSDFMap);

    TEXTURE2D(_Ramp);
    SAMPLER(sampler_Ramp);

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
        half4 OUT;

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
        /////////////////采样贴图/////////////////
        /////////////////////////////////////////
        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
        //采样环境贴图,面部只采样一个方向，避免形成立体效果
        float3 envDifColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, forwardWS, 6).rgb;
        //ramp图：采样对应的ramp图，暗部叠加ramp，和亮部用lambert混合
        half3 envRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, half2(length(lightColor*_ShadowDarkness), vDirectLightMapRamp)).rgb;

        /////////////////////////////////////////
        ///////////////计算PBR参数////////////////
        /////////////////////////////////////////
        //PBR diffuseMask
        float3 diffuseMask = BTDFDisney(normalWS, viewDirectionWS, lightDirWS, _Roughness);

        /////////////////////////////////////////
        ///////////////////NPR///////////////////
        /////////////////////////////////////////
        //面部SDF
        float faceShadow = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, IN.uv2, lightDirWS, normalWS, forwardWS, leftWS).x;

        //环境光(暗部颜色）
        float3 envDif = envDifColor * baseColor.rgb * _EnvDif + envRamp * baseColor;
        float3 lightDif = lightColor.rgb * baseColor + envDif.rgb;
        float3 diffusionColor = lerp(envDif, lightDif, faceShadow);

        //混合pbr颜色
        float3 pbrDiffuseMerge = diffuseMask * baseColor.rgb;
        pbrDiffuseMerge = lerp(diffusionColor, pbrDiffuseMerge, _DisneyDiffuseMergeRatio);

        //////////////////////////////////////////
        //////////////////前向光///////////////////
        //////////////////////////////////////////
        //叠加菲尼尔遮罩，增强立体感
        float3 darkEdge = lerp(pbrDiffuseMerge, pbrDiffuseMerge * dot(viewDirectionWS, normalWS), _FrontLight);

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
        float3 color = otherLightColor + darkEdge;

        OUT = half4(color.xyz, 1);

        return OUT;
    }
    ENDHLSL



    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "LightMode"="UniversalForward"
        }
        Pass
        {
            ZTest Always
            Stencil
            {
                Ref 250
                Comp Less
                Pass Keep
                ZFail Keep
            }
            Tags
            {
                "LightMode"="Brow"
            }
            HLSLPROGRAM
            #pragma vertex vertFace
            #pragma fragment fragFace
            ENDHLSL
        }
        Pass
        {
            Tags
            {
                "LightMode"="Outline"
            }
        }

        //        UsePass "Universal Render Pipeline/Lit/ShadowCaster"       
    }
}