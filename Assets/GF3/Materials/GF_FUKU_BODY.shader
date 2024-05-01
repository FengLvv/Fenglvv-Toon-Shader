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

        [Header(Lambert)]
        _DichotomyThreshold ("二分线", Range(0,1)) = 0.5
        _DichotomyRange ("二分渐变范围", Range(0,0.1)) = 0.02

        _ShadowIntensity ("阴影强度", Range(0,1)) = 0.5
        _ShadowColor ("阴影颜色", Color) = (1,1,1,1)

        _RampDistribution ("ramp颜色贡献", Range(0,5)) = 1
        [HDR]_GradientColor ("RGB:渐变颜色,W:混合渐变", Color) = (1,1,1,1)
        _EnvDistribution("环境颜色贡献", Range(0,10)) = 0.5

        _LightColorEffect("主光照颜色影响", Range(0,2)) = 1

        [Header(PBR)]
        _DisneyDiffuseMergeRatio ("pbr漫反射混入量", Range(0,1)) = 0.5
        _SpecularRatio ("高光比率", Range(0,1)) = 0.5
        _AOIntensity ("AO强度", Range(0,1)) = 0.5


        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5
    }

    HLSLINCLUDE
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"
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
    #pragma shader_feature _PBR

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


    TEXTURE2D(_LightCamTexture);
    SAMPLER(sampler_LightCamTexture);
    matrix _LighCamtVP;
    CBUFFER_START(UnityPerMaterial)
        float _AOIntensity;
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


    real3 reverseACES(float3 color)
    {
        return 3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
    }

    float calculateLightCamShadow(float3 worldPos)
    {
        float4 posCS = mul(_LighCamtVP, float4(worldPos, 1));
        posCS.xyz /= posCS.w;
        float2 uv = posCS.xy * 0.5 + 0.5;
        float depth = posCS.z;
        float bias = 0.005;
        float textureBias = 1 / 1024. * (_DichotomyRange * 100);
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
        //TBN
        float3x3 matWS2TS = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
        //光照参数
        Light mainLight = GetMainLight();
        float3 lightDirWS = normalize(mainLight.direction);
        float3 lightColor = mainLight.color;
        lightColor *= _LightColorEffect;

        //相机参数
        float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS.xyz);
        //半向量
        float3 halfVecWS = normalize(viewDirectionWS + lightDirWS);
        float3 normalWS;

        //法线信息 
        half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, IN.uv));
        normalWS = mul(normalTS, matWS2TS);

        half4 rmo = SAMPLE_TEXTURE2D(_RMO, sampler_RMO, IN.uv);
        float roughness = rmo.r;
        float metallic = rmo.g;
        float occlusion = rmo.b;

        /////////////////////////////////////////
        /////////////////采样贴图/////////////////
        /////////////////////////////////////////
        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
        float3 envCol = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, half3(reflect(-viewDirectionWS, normalWS)), 5).rgb * baseColor;

        /////////////////////////////////////////
        ///////////////////NPR///////////////////
        /////////////////////////////////////////
        //漫反射
        float lambert = dot(lightDirWS, normalWS);
        float halfLambert = lambert * 0.5 + 0.5;
        float shadow = calculateLightCamShadow(IN.positionWS.xyz); // 高质量阴影
        halfLambert = lerp(halfLambert, halfLambert * occlusion, _AOIntensity);
        float LambertWithShadow = saturate(lerp(lambert, min(lambert, shadow), _ShadowIntensity));

        //二分线
        float stepLambert = smoothstep(_DichotomyThreshold - _DichotomyRange, _DichotomyThreshold + _DichotomyRange, halfLambert);
        float stepLambertWithShadow = min(stepLambert, shadow);
        float gradientPart = stepLambertWithShadow * (1 - stepLambertWithShadow);

        //ramp图：采样对应的ramp图，暗部叠加ramp，和亮部用lambert混合
        half3 directLightRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, half2(halfLambert, vDirectLightMapRamp)).rgb * baseColor;

        //环境光(暗部颜色）: 暗部颜色（削弱光源）+ramp影响的颜色+环境光
        float3 darkDif = _ShadowColor.rgb * lightColor * baseColor + directLightRamp * _RampDistribution + envCol.rgb * _EnvDistribution;

        float3 dayDif = darkDif + lightColor.rgb * baseColor.rgb; //亮部颜色
        float3 diffusionColor = lerp(darkDif, dayDif, stepLambertWithShadow);

        //高饱和度渐变：获取灰度，和源颜色lerp出高纯度颜色
        float3 saturationGradiantCol = lerp(diffusionColor, diffusionColor + _GradientColor, gradientPart);


        /////////////////////////////////////////  
       //////////////////PBR////////////////////
       /////////////////////////////////////////
        //参数准备
        float NdotL = max(saturate(dot(normalWS, lightDirWS)), 0.000001);
        float VdotH = max(saturate(dot(viewDirectionWS, halfVecWS)), 0.000001);
        float NdotH = max(saturate(dot(normalWS, halfVecWS)), 0.000001);
        float NdotV = max(saturate(dot(normalWS, viewDirectionWS)), 0.000001);
        float HdotV = max(saturate(dot(halfVecWS, viewDirectionWS)), 0.000001);
        //PBR specularMask
        float3 BRDF = CalculateBRDF(NdotV, NdotL, HdotV, NdotH, VdotH, roughness, baseColor.rgb, metallic);
        float3 specularCol = BRDF * NdotL * lightColor.rgb;
        //高光 ramp
        float specRampMask = length(specularCol);
        half3 mainLightSpecRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, half2(specRampMask, vLightSpecRamp)).rgb;

        //PBR diffusionMask
        half3 fresnel = BRDF_F(baseColor.rgb, metallic, VdotH);
        float kd = (1 - length(fresnel)) * (1 - metallic);
        float BTDF = BTDFDisney(normalWS, viewDirectionWS, lightDirWS, (roughness + roughness));
        float3 disneyDiffuse = kd * BTDF * baseColor * LambertWithShadow * lightColor.rgb + darkDif;

        //混合pbr颜色
        float3 pbrMerge = lerp(saturationGradiantCol, disneyDiffuse, _DisneyDiffuseMergeRatio);
        pbrMerge = lerp(pbrMerge, pbrMerge + BRDF + mainLightSpecRamp, _SpecularRatio);

        //////////////////////////////////////////
        //////////////////前向光///////////////////
        //////////////////////////////////////////
        //叠加菲尼尔遮罩，增强立体感
        float3 darkEdge = lerp(pbrMerge, pbrMerge * dot(viewDirectionWS, normalWS), _FrontLight);

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

            halfVecWS = normalize(viewDirectionWS + addLight.direction).xyz;
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