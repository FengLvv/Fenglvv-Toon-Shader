#ifndef _GFBasic
#define _GFBasic

#define vAdditionalLightRamp  0.8
#define vMetalEnvSpecRamp  0.55
#define vLightSpecRamp  0.3
#define vDirectLightMapRamp 0.05

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Assets/MyMaterial/Repo/PBR.hlsl"
#include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"


//贴图
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
#if defined(_HAIR)
TEXTURE2D(_FlowMap);
SAMPLER(sampler_FlowMap);
TEXTURE2D(_HairBias);
SAMPLER(sampler_HairBias);
#endif
#if defined(_HAIR_FRONT)
TEXTURE2D(_HairSpecularMap);
SAMPLER(sampler_HairSpecularMap);
#endif
#if defined(_FACE)
TEXTURE2D(_FaceSDFMap);
SAMPLER(sampler_FaceSDFMap);
#endif
#if defined(_PBR)
TEXTURE2D(_RMO);
SAMPLER(sampler_RMO);
TEXTURE2D(_Normal);
SAMPLER(sampler_Normal);
#endif

float _OutlineWidth = 0.2f;
float _InlineWidth = 0.02f;
TEXTURE2D(_Ramp);
SAMPLER(sampler_Ramp);

//屏幕深度
TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

CBUFFER_START(UnityPerMaterial)
    #ifndef _PBR
    float _Roughness = 1;
    float _Metallic = 0;
    #else
    float _AOIntensity; 
    #endif


    #if defined(_HAIR)
    float4 _HairBias_ST;
    float _BiasScale;
    float4 _HairCol;
    #endif


    #if defined(_HAIR_FRONT)
    float _FringeShadowWidth;
    float4 _FringeShadowColor;
    #endif

    float _ColorAdjust;
    float _FrontLight;
    #ifndef _FACE
    float _DichotomyThreshold;
    float _DichotomyRange;
    #endif
    float _ShadowDarkness;
    float4 _ShadowColor;

    float _DisneyDiffuseMergeRatio;

    #ifndef _FACE
    float _GradiantSaturation;
    float4 _GradiantColor;
    #endif
float _LightColorEffect;

    float _EnvDif;
    float _EnvSpec;

    float _SpecularIntensity;
    float4 _SpecularColor;
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


real3 reverseACES(float3 color)
{
    return 3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
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
    //阴影
    OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS.xyz);
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
    //角色方向
    float3 forwardWS = TransformObjectToWorldDir(float3(0, 0, 1));
    float3 leftWS = TransformObjectToWorldDir(float3(1, 0, 0));

    float3 normalWS = IN.normalWS;

    #ifdef _HAIR
    float2 flowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, IN.uv).rg;
    float3 hairFlowTS = float3(0,flowMap.x ,flowMap.y);
    hairFlowTS = normalize(float3(2*(flowMap.x-0.5),2*(flowMap.y-0.5),0));
    float3 hairFlowWS = mul(hairFlowTS, matWS2TS);
    float3 hairTangentWS = normalize(hairFlowWS);
    #endif

    //法线信息 
    #if defined(_PBR)
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, IN.uv));
    normalWS = mul(normalTS, matWS2TS);

    half4 rmo = SAMPLE_TEXTURE2D(_RMO, sampler_RMO, IN.uv);
    float roughness = rmo.r;
    float metallic = rmo.g;
    float occlusion = rmo.b;
    #else
    float roughness = _Roughness;
    float metallic = _Metallic;
    #endif

    /////////////////////////////////////////
    /////////////////采样贴图/////////////////
    /////////////////////////////////////////
    half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

    //采样环境贴图,面部只采样一个方向，避免形成立体效果
    #ifdef _FACE
    float3 envDif = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, forwardWS, 6).rgb;
    float3 envSpec = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, forwardWS, roughness*5).rgb;
    #else
    float3 envDif = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, float3(00,0,0), 8).rgb;
    float3 envSpec = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, half3(reflect(-viewDirectionWS, normalWS)), roughness*5).rgb;
    #endif


    //////////////////////////////////////////
    ////////////////预处理贴图/////////////////
    /////////////////////////////////////////
    //toneMap 调色baseColor
    float3 toneMapColor = reverseACES(baseColor.rgb);
    float3 baseColAdjusted = lerp(toneMapColor, baseColor.rgb, _ColorAdjust);

    /////////////////////////////////////////
    ///////////////计算PBR参数////////////////
    /////////////////////////////////////////
    //参数准备
    float NdotL = max(saturate(dot(normalWS, lightDirWS)), 0.000001);
    float VdotH = max(saturate(dot(viewDirectionWS, halfVecWS)), 0.000001);
    float NdotH = max(saturate(dot(normalWS, halfVecWS)), 0.000001);
    float NdotV = max(saturate(dot(normalWS, viewDirectionWS)), 0.000001);
    float HdotV = max(saturate(dot(halfVecWS, viewDirectionWS)), 0.000001);

    //PBR specularMask
    float3 BRDF = CalculateBRDF(NdotV, NdotL, HdotV, NdotH, VdotH, roughness, baseColor.rgb, metallic);
    float3 specularMask = BRDF * NdotL;

    //PBR diffusionMask
    half3 fresnel = BRDF_F(baseColor.rgb, metallic, VdotH);
    float kd = (1 - length(fresnel)) * (1 - metallic);
    float BTDF = BTDFDisney(normalWS, viewDirectionWS, lightDirWS, roughness);
    float3 diffuseMask = kd * BTDF;

    /////////////////////////////////////////
    ///////////////////NPR///////////////////
    /////////////////////////////////////////
    //+ 环境光
    float3 envDifCol = lerp(baseColAdjusted.rgb, envDif * baseColAdjusted.rgb, _EnvDif);

    //+ 漫反射
    float halfLambert = dot(lightDirWS, IN.normalWS) * 0.5 + 0.5;
    //-> + PBR上AO
    #ifdef _PBR
    halfLambert = lerp(halfLambert, halfLambert * occlusion, _AOIntensity);
    #endif

    float stepLambert = halfLambert;
    //-> - 面部SDF
    #ifdef _FACE
    float3 sdfShadowFaceSample = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, IN.uv2, lightDirWS, normalWS, forwardWS, leftWS).x;
    float sdfShadowFace=  sdfShadowFaceSample.x;
    halfLambert =stepLambert= saturate(sdfShadowFace );
    #else
    stepLambert = smoothstep(_DichotomyThreshold - _DichotomyRange, _DichotomyThreshold + _DichotomyRange, halfLambert);
    #endif

    //-> + ramp图：采样对应的ramp图，暗部叠加ramp，和亮部用lambert混合
    half2 uvDirectLightRamp = half2(halfLambert, vDirectLightMapRamp);
    half3 directLightRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, uvDirectLightRamp).rgb;
    float3 dayRampDiffuse = lightColor.rgb * envDifCol.rgb; //亮部颜色
    float3 darkRampDiffuse = _ShadowColor.rgb * directLightRamp * envDifCol.rgb * lightColor.rgb;
    darkRampDiffuse = lerp(darkRampDiffuse, dayRampDiffuse, _ShadowDarkness);
    float3 diffusionColor = lerp(darkRampDiffuse, dayRampDiffuse, stepLambert);

    //-> + 高饱和度渐变：获取灰度，和源颜色lerp出高纯度颜色
    float3 saturationGradiantCol = diffusionColor;
    #ifndef _FACE
    float halfLambertGradiantPartMask = 1 * exp((-pow(halfLambert - _DichotomyThreshold, 2)) / (2 * pow(_DichotomyRange, 2)));
    float gray = dot(baseColAdjusted.rgb, float3(0.299, 0.587, 0.114));
    half3 gradiantCol = lerp(gray.xxx, baseColAdjusted, _GradiantSaturation * 2);
    gradiantCol = lerp(gradiantCol, _GradiantColor.rgb, _GradiantColor.w);
    saturationGradiantCol = lerp(diffusionColor, gradiantCol, halfLambertGradiantPartMask);
    #endif

    //-> + 混合pbr颜色
    float3 pbrDiffuseMerge = diffuseMask * baseColor.rgb;
    pbrDiffuseMerge = lerp(saturationGradiantCol, pbrDiffuseMerge, _DisneyDiffuseMergeRatio);

    //+ 高光
    float3 specCol = pbrDiffuseMerge;
    //-> +| 后发和其他高光
    #if defined(_HAIR)
    float hairBias = SAMPLE_TEXTURE2D(_HairBias, sampler_HairBias, IN.uv2*_HairBias_ST.xy + _HairBias_ST.zw).r * 2 - 1;
    float3 H = normalize(lightDirWS + viewDirectionWS);
    float3 T= normalize(hairTangentWS+hairBias*normalWS*_BiasScale);
    float dotTH = dot(T, H);
    float sinTH = sqrt(1.0 - dotTH*dotTH);
    float sinTHPow1=sinTH*sinTH*sinTH*sinTH*sinTH*sinTH*sinTH*sinTH*sinTH;
    sinTHPow1*=sinTHPow1*sinTHPow1*sinTHPow1;
    float dirAtten = smoothstep(-1.0, 0.0, dot(T, H));
    float specRampMask1= saturate(dirAtten * sinTHPow1);
    specCol= lerp(pbrDiffuseMerge.xyz,pbrDiffuseMerge* _HairCol.xyz , specRampMask1);

    float sinTHPow2=sinTH*sinTH*sinTH*sinTH*sinTH*sinTH;
    sinTHPow2*=sinTHPow2*sinTHPow2*sinTHPow2*sinTHPow2;
    sinTHPow2*=sinTHPow2*sinTHPow2*sinTHPow2*sinTHPow2*sinTHPow2*sinTHPow2*sinTHPow2;   
    float specRampMask2= dirAtten * sinTHPow2;
    specCol += specRampMask2*lightColor*_SpecularIntensity*_SpecularColor.rgb;
    //-> +| 前发高光
    # elif  defined(_HAIR_FRONT)
    float SpecOffsetValue = viewDirectionWS.y > 0 ? viewDirectionWS.y * 0.3 : viewDirectionWS.y * 1.3;
    float3 SpecValue = SAMPLE_TEXTURE2D(_HairSpecularMap, sampler_HairSpecularMap, float2(IN.uv2.x,saturate(IN.uv2.y-SpecOffsetValue*0.05))).rgb;
    //调整时间
    float3 SpecColorHair = (NdotV * 0.5 + 0.5) * smoothstep(0.45, 0.55, NdotL * 0.5 + 0.5) * SpecValue.x ;
    float2 normalHorizon = normalize(float2(normalWS.x,  normalWS.z));
    float fresnelHorizon = dot(normalHorizon, normalize(viewDirectionWS.xz));
    fresnelHorizon = saturate(fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon*fresnelHorizon  -0.3);
    SpecColorHair = SpecColorHair * fresnelHorizon* _SpecularIntensity ;
    specCol = pbrDiffuseMerge+ SpecColorHair;
    #else
    //-> +| GGX高光
    //高光 mask:PBR的specularMask替换 Blinn Phong
    float specRampMask = length(specularMask) * 10;
    //高光 ramp
    half2 uvLightSpecRamp = half2(specRampMask, vLightSpecRamp);
    half3 mainLightSpecRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, uvLightSpecRamp).rgb;
    //高光叠加
    float3 lightSpecCol = mainLightSpecRamp * _SpecularIntensity * _SpecularColor.rgb;
    //叠加环境光
    lightSpecCol = lerp(lightSpecCol, lightSpecCol * envSpec, _EnvSpec);
    //高光叠加
    specCol = lightSpecCol + pbrDiffuseMerge;
    #endif

    //////////////////////////////////////////
    //////////////////前向光///////////////////
    //////////////////////////////////////////
    //叠加菲尼尔遮罩，增强立体感
    half fresnelMask = lerp(dot(viewDirectionWS, normalWS), 1, _FrontLight);
    half3 frontLightCol = fresnelMask * specCol;

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
    float3 color = lerp(otherLightColor, frontLightCol, 0.7);


    // color=dayRampDiffuse;
    #ifdef _FACE
    // color=fresnelMask;
    #endif


    OUT = half4(color.xyz, 1);

    return OUT;
}




/////////////////////////////////////////////////////////////////////
////////////////////////////描边//////////////////////////////////////
/////////////////////////////////////////////////////////////////////
VaryingsOutline outline_vert(AttributeOutline IN)
{
    float4 scaledScreenParams = GetScaledScreenParams();
    VaryingsOutline OUT;
    float weight = 5; //以后放到color.b

    // 处理tangent空间的法线
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    float3 tangentWS = TransformObjectToWorldDir(IN.tangentOS.xyz);
    float3 bitangentWS =normalize( cross(normalWS, tangentWS) * IN.tangentOS.w);

    float3x3 matW2T = float3x3(tangentWS, bitangentWS, normalWS);
    float3 smoothNormalTS= normalize(IN.color.xyz);

    float3 smoothNormalWS = mul(smoothNormalTS, matW2T);

    // 如果存的已经是物体空间的法线：_OutlineWidth
    // smoothNormalOS = float3(IN.color.r, IN.color.g, IN.color.b);

    //计算法线从物体到裁切空间的矩阵 -> 计算裁切空间的法线
    OUT.positionHCS = createChangedOutlineInVert(IN.positionOS, _OutlineWidth, weight, _OutlineWidth, smoothNormalWS);
    // OUT.positionHCS = createChangedOutlineInVert(IN.positionOS, _OutlineWidth, weight, _OutlineWidth, smoothNormalWS);
    OUT.positionVS = mul(UNITY_MATRIX_MV, IN.positionOS).xyz;
    return OUT;
}

half4 outline_frag(VaryingsOutline IN) : SV_Target
{
    half4 color = lerp(0, 0.2, -IN.positionVS.z * 0.1);
    return color;
}


/////////////////////////////////////////////////////////////////////
////////////////////////////头发阴影///////////////////////////////////
/////////////////////////////////////////////////////////////////////

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
    #if defined(_HAIR_FRONT)
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
    #endif
    return OUT;
}
half4 fringe_frag(VaryingsHair IN) : SV_Target
{
    #if defined(_HAIR_FRONT)
    half4 color = float4(_FringeShadowColor.xyz * _FringeShadowColor.w, _FringeShadowColor.w);
    // color = float4(lightDirWS.xyz, 1);
    return color;

    #else
    return 0;
    #endif
}

/////////////////////////////////////////////////////////////////////
////////////////////////////内描边///////////////////////////////////
////////////////////////////////////////////////////////////////////
/*********如果我们把每个点的位置向着法线方向位移一段距离，再根据位移后的坐标采样相机深度图，把深度和自己的深度做对比，如果差值大于一个阈值，那么就是边缘。*********/
struct AttributeInline {
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
};

struct VaryingsInline {
    float4 positionHCS : SV_POSITION;
    float3 positionVS : TEXCOORD0;
    float3 positionWS : TEXCOORD2;
    float3 normalWS : NORMAL;
};

VaryingsInline inline_vert(AttributeInline IN)
{
    VaryingsInline OUT;
    VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
    VertexNormalInputs normals = GetVertexNormalInputs(IN.normalOS);
    OUT.positionHCS = vertices.positionCS;
    OUT.positionWS = vertices.positionWS;
    OUT.normalWS = normals.normalWS;
    OUT.positionVS = mul(UNITY_MATRIX_MV, IN.positionOS).xyz;
    return OUT;
}

half4 inline_frag(VaryingsInline IN) : SV_Target
{
    half4 OUT;
    float3 normalWS = normalize(IN.normalWS);
    float3 positionWS = IN.positionWS;
    float3 positionVS = IN.positionVS;
    float3 cameraDirWS = GetWorldSpaceNormalizeViewDir(positionWS);

    //找到法线方向的点
    float inlineWidth = _InlineWidth * (atan(-_InlineWidth + 5) * INV_PI + 0.6);
    float3 offsetPositionWS = positionWS + normalWS * inlineWidth;
    //clip空间的位置
    float3 offsetPositionVS = TransformWorldToView(offsetPositionWS);
    float4 offsetPositionHCS = mul(unity_CameraProjection, float4(offsetPositionVS, 1));
    // float4 offsetPositionHCS =TransformWorldToHClip(positionWS);

    //除以z进入NDC，然后映射到0-1
    float2 screenUV = offsetPositionHCS.xy / offsetPositionHCS.w * 0.5 + 0.5;
    float depthOffset = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).x, _ZBufferParams);
    float realDepth = -positionVS.z;
    float depthDiff = abs(depthOffset - realDepth);
    float inlineMask = step(0.2, depthDiff);

    Light mainLight = GetMainLight();
    float lambert = saturate(dot(normalWS, mainLight.direction));
    float3 mainLightColor = lambert * atan(3 * mainLight.color) * 3 * INV_PI;

    float3 otherLightColor = 0;
    float otherLightAttenuation = 0;

    //获取其他光源详细
    #ifdef _ADDITIONAL_LIGHTS
    uint lightsCount = GetAdditionalLightsCount(); //获取灯光总数
    for (uint lightIndex = 0u; lightIndex < lightsCount; ++lightIndex)
    {
        //用来循环，得到index
        Light addLight = GetAdditionalLight(lightIndex, positionWS); //输入index，获取光照
        half3 eachLightColor = addLight.color * addLight.distanceAttenuation;

        float3 halfVecWS = normalize(cameraDirWS + addLight.direction);
        float blinnPhone = mul(halfVecWS, normalWS);
        blinnPhone*=blinnPhone*blinnPhone*blinnPhone*blinnPhone*blinnPhone;

        otherLightColor += blinnPhone * eachLightColor;
        otherLightAttenuation += blinnPhone;    } 
    #endif

    otherLightColor *= inlineMask;
    mainLightColor *= inlineMask;
    float3 color = otherLightColor + mainLightColor;

    float alpha = length(color);
    OUT = float4(color, alpha);
    return OUT;
}

#endif
