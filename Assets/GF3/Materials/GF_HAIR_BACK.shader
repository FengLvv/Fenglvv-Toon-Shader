Shader "3R2/GF/HAIR/BACK"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset]_FlowMap ("头发高光", 2D) = "white" {}
        _HairBias ("头发纹理", 2D) = "white" {}
        _BiasScale ("头发纹理强度", Range(0,3)) = 2
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}
        [HDR] _HairCol ("头发过渡层颜色", Color) = (1,1,1,1)


        [Header(Lambert)]
        _DichotomyThreshold ("二分线", Range(0,1)) = 0.5
        _DichotomyRange ("二分渐变范围", Range(0,0.5)) = 0.02

        _ShadowIntensity ("阴影强度", Range(0,1)) = 0.5
        _ShadowColor ("阴影颜色", Color) = (1,1,1,1)

        _RampDistribution ("ramp颜色贡献", Range(0,5)) = 1
        [HDR]_GradientColor ("RGB:渐变颜色,W:混合渐变", Color) = (1,1,1,1)
        _EnvDistribution("环境颜色贡献", Range(0,10)) = 0.5

        _LightColorEffect("主光照颜色影响", Range(0,2)) = 1


        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5

        [Header(Specular)]
        _SpecularIntensity ("高光强度", Range(0,10)) = 1
        _SpecularColor ("高光颜色", Color) = (1,1,1,1)
    }

    HLSLINCLUDE
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
    #pragma shader_feature _ _PART_HAIR _PART_FACE _PART_BODY _PART_CLOTH _PART_EYE
    #pragma shader_feature_local _HAIR_FRONT



    #define vAdditionalLightRamp  0.8
    #define vMetalEnvSpecRamp  0.55
    #define vLightSpecRamp  0.3
    #define vDirectLightMapRamp 0.05



    //贴图
    TEXTURE2D(_BaseMap);
    SAMPLER(sampler_BaseMap);

    TEXTURE2D(_RMO);
    SAMPLER(sampler_RMO);
    TEXTURE2D(_Normal);
    SAMPLER(sampler_Normal);

    TEXTURE2D(_Ramp);
    SAMPLER(sampler_Ramp);

    TEXTURE2D(_FlowMap);
    SAMPLER(sampler_FlowMap);

    TEXTURE2D(_HairBias);
    SAMPLER(sampler_HairBias);

    TEXTURE2D(_LightCamTexture);
    SAMPLER(sampler_LightCamTexture);
    matrix _LighCamtVP;
    CBUFFER_START(UnityPerMaterial)
        float4 _HairBias_ST;
        float _BiasScale;
        float4 _HairCol;

        float _SpecularIntensity;

        float4 _SpecularColor;
        float _ShadowIntensity;

        float _FrontLight;
        float _DichotomyThreshold;
        float _DichotomyRange;
        float _RampDistribution;
        float4 _ShadowColor;
        float4 _GradientColor;
        float _DisneyDiffuseMergeRatio;

        float _LightColorEffect;
        float _SpecularRatio;

        float _EnvDistribution;
        float _FringeShadowWidth;
        float4 _FringeShadowColor;

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
    };

    Varyings vert(Attributes IN)
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
        return OUT;
    }
    
    half4 frag(Varyings IN) : SV_Target
    {
        half4 OUT;

        //////////////////////////////////////////
        //////////////////参数准备/////////////////
        /////////////////////////////////////////
        float3x3 matWS2TS = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);

        //光照参数
        Light mainLight = GetMainLight();
        float3 lightDirWS = normalize(mainLight.direction);
        float3 lightColor = mainLight.color;
        lightColor *= _LightColorEffect;

        //相机参数
        float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS.xyz);
        float3 normalWS = normalize(IN.normalWS);

        /////////////////////////////////////////
        /////////////////采样贴图/////////////////
        /////////////////////////////////////////
        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
        float3 envCol = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, half3(reflect(-viewDirectionWS, normalWS)), 5).rgb * baseColor;


        float2 flowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, IN.uv).rg;
        float3 hairFlowTS = float3(0, flowMap.x, flowMap.y);
        hairFlowTS = normalize(float3(2 * (flowMap.x - 0.5), 2 * (flowMap.y - 0.5), 0));
        float3 hairFlowWS = mul(hairFlowTS, matWS2TS);
        float3 hairTangentWS = normalize(IN.tangentWS);

        /////////////////////////////////////////
        ///////////////////NPR///////////////////
        /////////////////////////////////////////
        //漫反射
        float lambert = dot(lightDirWS, normalWS);
        float halfLambert = lambert * 0.5 + 0.5;

        //二分线
        float stepLambert = smoothstep(_DichotomyThreshold - _DichotomyRange, _DichotomyThreshold + _DichotomyRange, halfLambert);
        float gradientPart = stepLambert * (1 - stepLambert);

        //ramp图：采样对应的ramp图，暗部叠加ramp，和亮部用lambert混合
        half3 directLightRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, half2(halfLambert, vDirectLightMapRamp)).rgb * baseColor;

        //环境光(暗部颜色）: 暗部颜色（削弱光源）+ramp影响的颜色+环境光
        float3 darkDif = _ShadowColor.rgb * lightColor * baseColor + envCol.rgb * _EnvDistribution;

        float3 dayDif = darkDif + lightColor.rgb * baseColor.rgb; //亮部颜色
        float3 diffusionColor = lerp(darkDif + directLightRamp * _RampDistribution, dayDif, stepLambert);

        //高饱和度渐变：获取灰度，和源颜色lerp出高纯度颜色
        float3 saturationGradiantCol = lerp(diffusionColor, diffusionColor + _GradientColor, gradientPart);


        float hairBias = SAMPLE_TEXTURE2D(_HairBias, sampler_HairBias, IN.uv2*_HairBias_ST.xy + _HairBias_ST.zw).r * 2 - 1;
        float3 H = normalize(lightDirWS + viewDirectionWS);
        float3 T = normalize(hairTangentWS + hairBias * normalWS * _BiasScale);
        float dotTH = dot(T, H);
        float sinTH = sqrt(1.0 - dotTH * dotTH);
        float sinTHPow1 = sinTH * sinTH * sinTH * sinTH * sinTH * sinTH * sinTH * sinTH * sinTH;
        sinTHPow1 *= sinTHPow1 * sinTHPow1 * sinTHPow1;
        float dirAtten = smoothstep(-1.0, 0.0, dot(T, H));
        float specRampMask1 = saturate(dirAtten * sinTHPow1);
        float3 specCol = lerp(saturationGradiantCol.xyz, saturationGradiantCol * _HairCol.xyz, specRampMask1);

        float sinTHPow2 = sinTH * sinTH * sinTH * sinTH * sinTH * sinTH;
        sinTHPow2 *= sinTHPow2 * sinTHPow2 * sinTHPow2 * sinTHPow2;
        sinTHPow2 *= sinTHPow2 * sinTHPow2 * sinTHPow2 * sinTHPow2 * sinTHPow2 * sinTHPow2 * sinTHPow2;
        float specRampMask2 = dirAtten * sinTHPow2;
        specCol += specRampMask2 * lightColor * _SpecularIntensity * _SpecularColor.rgb;

        //////////////////////////////////////////
        //////////////////前向光///////////////////
        //////////////////////////////////////////
        //叠加菲尼尔遮罩，增强立体感
        float3 darkEdge = lerp(specCol, specCol * dot(viewDirectionWS, normalWS), _FrontLight);

        //////////////////////////////////////////
        //////////////////多光源///////////////////
        //////////////////////////////////////////
        //获取其他光源详细
        float3 otherLightColor = 0;
        uint lightsCount = GetAdditionalLightsCount(); //获取灯光总数
        for (uint lightIndex = 0u; lightIndex < lightsCount; ++lightIndex)
        {
            //用来循环，得到index
            Light addLight = GetAdditionalLight(lightIndex, IN.positionWS); //输入index，获取光照
            half3 eachLightColor = addLight.color * addLight.distanceAttenuation;

            float3 halfVecWS = normalize(viewDirectionWS + addLight.direction).xyz;
            float blinnPhone = mul(halfVecWS, normalWS);
            blinnPhone *= blinnPhone * blinnPhone * blinnPhone * blinnPhone * blinnPhone;

            otherLightColor += eachLightColor * blinnPhone;
        }
        float3 color = darkEdge + otherLightColor;

        OUT = half4(color, 1);
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
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
  
        Pass
        {
            Tags
            {
                "LightMode"="Outline"
            }
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}