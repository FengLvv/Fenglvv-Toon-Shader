Shader "3R2/GF/HAIR/FRONT"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        [NoScaleOffset]_HairSpecularMap ("头发高光", 2D) = "white" {}
        [NoScaleOffset]_Ramp ("Ramp", 2D) = "white" {}

        [header(Hair)]
        _FringeShadowWidth ("刘海位移", Range(0,1)) = 0.5
        _FringeShadowColor ("刘海颜色", Color) = (1,1,1,1)

        [Header(Lambert)]
        _DichotomyThreshold ("二分线", Range(0,1)) = 0.5
        _DichotomyRange ("二分渐变范围", Range(0,0.5)) = 0.02

        _ShadowIntensity ("阴影强度", Range(0,1)) = 0.5
        _ShadowColor ("阴影颜色", Color) = (1,1,1,1)

        _RampDistribution ("ramp颜色贡献", Range(0,5)) = 1
        [HDR]_GradientColor ("RGB:渐变颜色,W:混合渐变", Color) = (1,1,1,1)
        _EnvDistribution("环境颜色贡献", Range(0,10)) = 0.5
        
         _SpecularIntensity("高光强度", Range(0,1)) = 0.5

        _LightColorEffect("主光照颜色影响", Range(0,2)) = 1

        [Header(Others)]
        _FrontLight( "前向光", Range(0,1)) = 0.5

        [Header(Write stencil)]
        _StencilWriteFringe("刘海模板写入值", Float) = 0
        _StencilReadShadow("刘海投影模板比较值（面部模板写入值)", Float) = 0
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

    TEXTURE2D(_HairSpecularMap);
    SAMPLER(sampler_HairSpecularMap);

    TEXTURE2D(_LightCamTexture);
    SAMPLER(sampler_LightCamTexture);
    matrix _LighCamtVP;
    CBUFFER_START(UnityPerMaterial)
        float _ShadowIntensity;
          float _SpecularIntensity;
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

        float NdotL = saturate(dot(normalWS, lightDirWS));
        float NdotV = saturate(dot(normalWS, viewDirectionWS));
        float SpecOffsetValue = viewDirectionWS.y > 0 ? viewDirectionWS.y * 0.3 : viewDirectionWS.y * 1.3;
        float3 SpecValue = SAMPLE_TEXTURE2D(_HairSpecularMap, sampler_HairSpecularMap, float2(IN.uv2.x,saturate(IN.uv2.y-SpecOffsetValue*0.05))).rgb;
        //调整时间
        float3 SpecColorHair = (NdotV * 0.5 + 0.5) * smoothstep(0.45, 0.55, NdotL * 0.5 + 0.5) * SpecValue.x;
        float2 normalHorizon = normalize(float2(normalWS.x, normalWS.z));
        float fresnelHorizon = dot(normalHorizon, normalize(viewDirectionWS.xz));
        fresnelHorizon = saturate(fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon * fresnelHorizon - 0.3);
        SpecColorHair = SpecColorHair * fresnelHorizon * _SpecularIntensity;
        float3 specCol =  saturationGradiantCol+SpecColorHair;

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

    struct AttributeHair {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;
    };

    struct VaryingsHair {
        float4 positionHCS : SV_POSITION;
        float4 length : TEXCOORD0;
    };

    VaryingsHair fringe_vert(AttributeHair IN)
    {
        VaryingsHair OUT = (VaryingsHair)0;
        float3 lightDirWS = GetMainLight().direction;
        float3 lightDirCS = TransformWorldToHClipDir(lightDirWS);
        VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz - float3(0, 0, 0.00001));
        float4 posCS = vertices.positionCS;

        float3 forwardDirWS = TransformObjectToWorldDir(float3(0, 0, 1));
        float3 lightDirH = normalize(float3(lightDirWS.x, 0, lightDirWS.z));
        float3 forwardVec = normalize(float3(forwardDirWS.x, 0, forwardDirWS.z));
        float shadowLength = atan(20 * (1 - abs(dot(forwardVec, lightDirH)))); //阴影长度
        shadowLength *= _FringeShadowWidth;
        OUT.positionHCS = float4(posCS.xy + -lightDirCS.xy * 0.01 * shadowLength, posCS.zw);
        OUT.length = shadowLength.xxxx;
        return OUT;
    }
    half4 fringe_frag(VaryingsHair IN) : SV_Target
    {
        half4 color = float4(_FringeShadowColor.xyz * _FringeShadowColor.w, _FringeShadowColor.w);
        // color = float4(lightDirWS.xyz, 1);
        return color;
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
            Stencil
            {
                Ref [_StencilWriteFringe]
                Comp Always
                Pass Replace
            }
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

            Name "Fringe"
            Tags
            {
                "LightMode"="Fringe"
            }
            stencil
            {
                Ref [_StencilReadShadow] //为当前片元设置参考值（0-255），与缓冲区的值比较          
                Comp Equal //比较操作          
            }
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex fringe_vert
            #pragma fragment fringe_frag
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