#ifndef _GFSHADER
#define _GFSHADER
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Assets/MyMaterial/Repo/BLENDCOLOR.hlsl"
#include "Assets/MyMaterial/Repo/PBR.hlsl"




# define  _OutlineWidth 0.001
# define  _FrontLight 0.7


//贴图
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_Normal);
SAMPLER(sampler_Normal);
TEXTURE2D(_HairSpecularMap);
SAMPLER(sampler_HairSpecularMap);
TEXTURE2D(_FaceSDFMap);
SAMPLER(sampler_FaceSDFMap);
TEXTURE2D(_RMO);
SAMPLER(sampler_RMO);
TEXTURE2D(_Ramp);
SAMPLER(sampler_Ramp);
TEXTURE2D(_Ramp2);
SAMPLER(sampler_Ramp2);
TEXTURECUBE(_Skybox);
SAMPLER(sampler_Skybox);
//屏幕深度
TEXTURE2D(_ScreenDepth);
SAMPLER(sampler_ScreenDepth);
TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);


CBUFFER_START(UnityPerMaterial)
    float _ColorAdjust;

    float _DichotomyThreshold;
    float _DichotomyRange;
    float _ShadowDarkness;
    float4 _ShadowColor;
    float _GradiantSaturation;
    float _PBRMergeRatio;
    float _PBREven;
    float _AOIntensity;
    float4 _GradiantColor;
    float4 _FringeShadowColor;
    float _FringeShadowWidth;
    float _EnvDif;
    float _EnvSpec;


    float _GlossyExp;
    float _SpecularIntensity;
    float4 _SpecularColor;
    float _Rim;
    float _RimIntensity;
    float4 _RimColor;
    float _ShadowRim;
    float _InnerLine;
    float _HonmuraLine;
CBUFFER_END



struct Attributes {
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float4 color : COLOR;
    float3 normalOS : NORMAL;
};

struct Varyings {
    float4 color : COLOR;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float4 positionHCS : SV_POSITION;
    float4 positionWS : TEXCOORD2;
    float3 normalWS : NORMAL;
    float3 tangentWS : TANGENT;
    float3 binormalWS : BINORMAL;
    float4 shadowCoord : TEXCOORD4;
};

struct Maps {
    half4 baseColor;
    half3 normalTS;
    half4 rmo;
    half roughness;
    half metallic;
    half occlusion;
};

float3 reverseACES(float3 color)
{
    return 3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
}

Maps GetGFMaps(float2 uv, float2 uv2, float4 vertexCol)
{
    //面部和头发粗糙度和金属度都取0
    Maps maps = (Maps)0;
    maps.baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    maps.normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_Normal, sampler_Normal, uv));
    #if defined( _PART_CLOTH) || defined( _PART_BODY)
    maps.rmo = SAMPLE_TEXTURE2D(_RMO, sampler_RMO, uv);
    maps.roughness = maps.rmo.r;
    maps.metallic = maps.rmo.g;
    maps.occlusion = maps.rmo.b;
    #else
    maps.roughness = 1;
    maps.metallic = 0;
    maps.occlusion = 1;
    #endif
    return maps;
}


Varyings vert(Attributes IN)
{
    Varyings OUT = (Varyings)0;
    VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
    VertexNormalInputs normals = GetVertexNormalInputs(IN.normalOS);
    OUT.uv = IN.uv;
    OUT.uv2 = IN.uv2;
    OUT.positionHCS = vertices.positionCS;
    OUT.positionWS = float4(vertices.positionWS, 1);
    OUT.color = IN.color;
    OUT.normalWS = normals.normalWS;
    OUT.tangentWS = normals.tangentWS;
    OUT.binormalWS = normals.bitangentWS;
    //阴影
    OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS.xyz);
    return OUT;
}

half4 frag(Varyings IN) : SV_Target
{
    half3 OUT;
    ////////////////////////////////////////参数准备////////////////////////////////////////////
    // Ramp uv
    half vAdditionalLightRamp = 0.8;
    half vMetalEnvSpecRamp = 0.55;
    half vLightSpecRamp = 0.3;
    half vDirectLightMapRamp = 0.05;
    // TBN矩阵
    float3x3 matW2T = float3x3(IN.tangentWS, IN.binormalWS, IN.normalWS);
    //光照参数
    Light mainLight = GetMainLight();
    float3 lightDirWS = mainLight.direction;
    float3 lightColor = mainLight.color;
    float3 lightAttenuation = mainLight.shadowAttenuation;
    //相机参数
    float3 viewDirectionWS = GetWorldSpaceViewDir(IN.positionWS.xyz);
    viewDirectionWS = normalize(viewDirectionWS);
    //半向量
    float3 halfVecWS = normalize(viewDirectionWS + lightDirWS);
    //角色方向
    float3 forwardWS = -TransformObjectToWorldDir(float3(0, 0, 1));
    float3 leftWS = TransformObjectToWorldDir(float3(1, 0, 0));
    //获取贴图
    Maps maps = GetGFMaps(IN.uv, IN.uv2, IN.color);
    half mainLightShadow = mainLight.shadowAttenuation;
    //处理贴图
    //处理法线
    #if defined( _PART_CLOTH) || defined( _PART_BODY)
        float3 normalWS = mul(maps.normalTS, matW2T);
    #else
    float3 normalWS = IN.normalWS;
    #endif
    //toneMap 调色basecolor
    float3 toneMapColor = reverseACES(maps.baseColor.rgb);
    float3 baseColAdjusted = lerp(toneMapColor, maps.baseColor.rgb, _ColorAdjust);
    //采样环境贴图,面部只采样一个方向，避免形成立体效果
    #ifdef _PART_FACE
    float3 envDif = SAMPLE_TEXTURECUBE_LOD(_Skybox, sampler_Skybox,     forwardWS, 6).rgb;
    float3 envSpec = SAMPLE_TEXTURECUBE_LOD(_Skybox, sampler_Skybox, forwardWS, maps.roughness*5).rgb;
    #else
    float3 envDif = SAMPLE_TEXTURECUBE_LOD(_Skybox, sampler_Skybox, half3(reflect(-viewDirectionWS, normalWS)), 8).rgb;
    float3 envSpec = SAMPLE_TEXTURECUBE_LOD(_Skybox, sampler_Skybox, half3(reflect(-viewDirectionWS, normalWS)), maps.roughness*5).rgb;
    #endif

    ////////////////////////////////////////叠加主光源PBR////////////////////////////////////////////
    float3 PBROUT;
    //参数准备
    float NdotL = max(saturate(dot(normalWS, lightDirWS)), 0.000001);
    float VdotH = max(saturate(dot(viewDirectionWS, halfVecWS)), 0.000001);
    float NdotH = max(saturate(dot(normalWS, halfVecWS)), 0.000001);
    float NdotV = max(saturate(dot(normalWS, viewDirectionWS)), 0.000001);
    float HdotV = max(saturate(dot(halfVecWS, viewDirectionWS)), 0.000001);
    float LdotV = max(saturate(dot(lightDirWS, viewDirectionWS)), 0.000001);
    //PBR specular
    float D = BRDF_D(NdotH, maps.roughness);
    float G = BRDF_G(NdotL, NdotV, maps.roughness);
    float3 F = BRDF_F(maps.baseColor, maps.metallic, VdotH);
    float3 BRDF = (D * G * F * 0.25) / (HdotV * NdotL);
    float specularMask = BRDF * NdotL;
    float3 pbrSpecMain = saturate(MYPI * lightColor * specularMask);
    //PBR diffusion
    float kd = (1 - length(F)) * (1 - maps.metallic);
    float BTDF = BTDFDisney(normalWS, viewDirectionWS, lightDirWS, maps.roughness);
    float3 pbrDiffuseMain = kd * lightColor * BTDF * maps.baseColor;
    //PBR直接光
    float3 PBRColor = pbrDiffuseMain + pbrSpecMain;
    PBROUT = PBRColor;


    ////////////////////////////////////NPR////////////////////////////////////////////
//////////////////////////////////全身漫反射 halfLambert////////////////////////////////////////////
    //叠加环境光
    float3 envDifColIN = baseColAdjusted.rgb;
    float3 envDifColOUT;
    envDifColOUT = lerp(envDifColIN, envDif * envDifColIN, _EnvDif);

    float3 halfLambertRampIN = envDifColOUT;
    float3 halfLambertRampOUT;
    ///阴影 mask 
    float halfLambert = dot(lightDirWS, IN.normalWS) * 0.5 + 0.5;

    //PBR材质的阴影叠上AO
    #if defined( _PART_CLOTH) || defined( _PART_BODY)
        halfLambert=lerp(halfLambert,halfLambert* maps.occlusion,_AOIntensity);
    #endif
    float stepLambert = smoothstep(_DichotomyThreshold - _DichotomyRange, _DichotomyThreshold + _DichotomyRange, halfLambert);

    //脸部叠加SDF阴影  
    #ifdef _PART_FACE
    //采样面部sdf
    float3 sdfShadowFaceSample = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, IN.uv2, lightDirWS, normalWS, forwardWS, leftWS).x;
    float sdfShadowFace=  sdfShadowFaceSample.x;
    halfLambert =stepLambert= saturate(sdfShadowFace );  
    #endif

    ///采样漫反射ramp
    half2 uvDirectLightRamp = half2(halfLambert, vDirectLightMapRamp);
    half3 directLightRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, uvDirectLightRamp).rgb;
    float3 DayRampdiffuse = lightColor.rgb * halfLambertRampIN.rgb;                                       //亮部颜色
    float3 DarkRampdiffuse = _ShadowColor.rgb * directLightRamp * halfLambertRampIN.rgb * lightColor.rgb; //暗部受到ramp影响
    DarkRampdiffuse = lerp(DarkRampdiffuse, DayRampdiffuse, _ShadowDarkness);                             //暗部颜色提亮  
    float3 RampDiffuse = lerp(DarkRampdiffuse, DayRampdiffuse, stepLambert);                              //根据阴影mask叠加亮暗部                           

    //高饱和度渐变
    float halfLmbertGradiantPartMask = 1 * exp((-pow(halfLambert - _DichotomyThreshold, 2)) / (2 * pow(_DichotomyRange, 2)));
    float gray = dot(halfLambertRampIN.rgb, float3(0.299, 0.587, 0.114));
    half3 gradiantCol = lerp(gray.xxx, halfLambertRampIN, _GradiantSaturation);
    gradiantCol = lerp(gradiantCol, _GradiantColor.rgb, _GradiantColor.w);
    float3 satuationGradiantCol = lerp(RampDiffuse, gradiantCol, halfLmbertGradiantPartMask);

    halfLambertRampOUT = satuationGradiantCol;


    ////////////////////////////////////////使用specMask叠加高光ramp////////////////////////////////////////////
    float3 specIN = halfLambertRampOUT;
    float3 specOUT;
    //高光 mask:从PBR的specularMask中获取
    float specRampMask = specularMask * 10;
    // specRampMask = pow(NdotH, (1-maps.roughness)*(1-maps.roughness)*50);//blinnPhone不太好看
    //高光 ramp
    half2 uvLightSpecRamp = half2(specRampMask, vLightSpecRamp);
    half3 mainlightSpecRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, uvLightSpecRamp).rgb;
    //高光叠加
    float3 lightSpecCol = mainlightSpecRamp * _SpecularIntensity;
    //叠加环境光
    lightSpecCol = lerp(lightSpecCol, lightSpecCol * envSpec, _EnvSpec);
    //高光叠加
    specOUT = specIN + lightSpecCol;

    //nose sdf spec,贴图用不了，自己画吧 
    float3 noseSDFSpecIN = specOUT; //TODO
    float3 noseSDFSpecOUT;
    #ifdef _PART_FACEs
    float3 sdfSpecNoceSample = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, float2(-IN.uv2.x, IN.uv2.y), lightDirWS, normalWS, forwardWS, leftWS);
    float sdfSpecNoce = min(sdfSpecNoceSample.y, sdfSpecNoceSample.z);
    noseSDFSpecOUT=noseSDFSpecIN+sdfSpecNoce*10;
    noseSDFSpecOUT=sdfSpecNoceSample.yyz;
    #else
    noseSDFSpecOUT = noseSDFSpecIN;
    #endif

    //头发高光
    float3 hairSpecIN = noseSDFSpecOUT;
    float3 hairSpecOUT;
    #ifdef _PART_HAIR
    //随着视角方向上下移动，高光在镜头上方时候移动更快
    float SpecOffsetValue = viewDirectionWS.y>0?viewDirectionWS.y*0.3:viewDirectionWS.y*1.3;
    float3 SpecValue= SAMPLE_TEXTURE2D(_HairSpecularMap, sampler_HairSpecularMap,float2(IN.uv2.x,saturate(IN.uv2.y-SpecOffsetValue*0.05)));
    float3 SpecColorHair =(NdotV*0.5+0.5)*smoothstep(0.45,0.55,NdotL*0.5+0.5)*SpecValue.x*mainLightShadow;
    float3 normalHorizon = float3(normalWS.x, 0, normalWS.z);
    float fresnelHorizon = dot(normalHorizon, viewDirectionWS);
    fresnelHorizon=saturate(pow(fresnelHorizon,3)-0.3);
    SpecColorHair=SpecColorHair*fresnelHorizon;
    hairSpecOUT = hairSpecIN + SpecColorHair;
    #else
    hairSpecOUT = hairSpecIN;
    #endif

    //粗糙度低的混合多一些
    float pbrMerge = lerp((1 - maps.roughness * maps.roughness), 0.5, _PBREven) * _PBRMergeRatio;
    PBROUT = lerp(hairSpecOUT, PBRColor, pbrMerge);

    ////////////////////////////////////////其他效果////////////////////////////////////////////
    //叠加菲尼尔遮罩，增强立体感
    half3 fresnelAddColIN = PBROUT;
    half3 fresnelAddColOUT;
    half fresnelMask = lerp(dot(viewDirectionWS, normalWS), 1, _FrontLight);
    fresnelAddColOUT = fresnelMask * fresnelAddColIN;

    OUT = PBROUT;

    // OUT = saturate(lerp(1-maps.roughness,0.5,-50))-maps.metallic*100;
    // OUT = maps.metallic;
    return half4(OUT, 1);
}


/////////////////////////////////////////////////////////////////////
////////////////////////////眉毛透视//////////////////////////////////
/////////////////////////////////////////////////////////////////////
struct AttributeEyebrow {
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float4 color : COLOR;
    float3 normalOS : NORMAL;
};

struct VaryingsEyebrow {
    float4 positionHCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float4 positionWS : TEXCOORD2;
    float2 screenCor : TEXCOORD3;
    float3 positionVS : TEXCOORD4;
    float4 color : COLOR;
    float3 normalWS : NORMAL;
    float3 tangentWS : TANGENT;
    float3 binormalWS : BINORMAL;
    float4 shadowCoord : TEXCOORD5;
};

VaryingsEyebrow eyebrow_vert(AttributeEyebrow IN)
{
    VaryingsEyebrow OUT = (VaryingsEyebrow)0;
    VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
    VertexNormalInputs normals = GetVertexNormalInputs(IN.normalOS);
    OUT.uv = IN.uv;
    OUT.uv2 = IN.uv2;
    float4 posCS = vertices.positionCS;
    OUT.positionHCS = posCS;
    OUT.positionWS = float4(vertices.positionWS, 1);
    OUT.color = IN.color;
    OUT.normalWS = normals.normalWS;
    OUT.tangentWS = normals.tangentWS;
    OUT.binormalWS = normals.bitangentWS;
    //计算屏幕空间UV,cs.xy/cs.w *0.5+0.5
    OUT.screenCor = vertices.positionNDC / vertices.positionNDC.w;
    OUT.positionVS = vertices.positionVS;
    //阴影
    OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS.xyz);
    return OUT;
}

half4 eyebrow_frag(VaryingsEyebrow IN) : SV_Target
{
    //只采样 SDF和 Main
    Light mainLight = GetMainLight();
    float3 lightDirWS = mainLight.direction;
    float3 lightAttenuation = mainLight.shadowAttenuation;
    float3 normalWS = IN.normalWS;
    float3 forwardWS = TransformObjectToWorldDir(float3(0, 0, 1));
    float3 leftWS = TransformObjectToWorldDir(float3(1, 0, 0));
    //采样SDF
    float sdfShadowMask = sampleSDF(_FaceSDFMap, sampler_FaceSDFMap, IN.uv2, lightDirWS, normalWS, forwardWS, leftWS);
    float shadow = 1 - sdfShadowMask;
    shadow = saturate(shadow + 0.02 + _ShadowDarkness);
    //采样漫反射ramp
    half2 uvDirectLightRamp = half2(shadow, 0.05);
    half3 directLightRamp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, uvDirectLightRamp).rgb;
    half3 baseCol = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb;
    float3 toneMapColor = reverseACES(baseCol.rgb);
    float3 baseColAdjusted = lerp(toneMapColor, baseCol.rgb, _ColorAdjust);
    //采样漫反射ramp
    half3 rampDiffuseCol = BlendMode_SoftLight(baseColAdjusted, directLightRamp);

    //添加阴影颜色
    half3 shadowedRampDiffuseCol = lerp(_ShadowColor.xyz * rampDiffuseCol, rampDiffuseCol, Luminance(directLightRamp));

    //获取当前物体真实深度
    float depthReal = -IN.positionVS.z;
    //获取深度图真实深度
    half depthSample = SAMPLE_TEXTURE2D(_ScreenDepth, sampler_ScreenDepth, IN.screenCor).r;
    float depthMap = LinearEyeDepth(depthSample, _ZBufferParams);
    if (depthReal < 1.2 && distance(depthReal, depthMap) > 0.05)
    {
        discard;
    }
    return half4(shadowedRampDiffuseCol, 1);
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


/////////////////////////////////////////////////////////////////////
////////////////////////////描边//////////////////////////////////////
/////////////////////////////////////////////////////////////////////
struct AttributeOutline1 {
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;

    float4 tangentOS : TANGENT;
};

struct VaryingsOutline1 {
    float4 positionHCS : SV_POSITION;
    float4 positionVS : TEXCOORD0;
};

VaryingsOutline1 outline_vert(AttributeOutline1 IN)
{
    VaryingsOutline1 OUT;

    float4 scaledScreenParams = GetScaledScreenParams();
    float weight = 5; //以后放到color.b

    // 处理tangent空间的法线
    float3 normalOS = normalize(IN.normalOS);
    float3 tangentOS = normalize(IN.tangentOS).xyz;
    float3 bitangentOS = normalize(cross(normalOS, tangentOS) * IN.tangentOS.w).xyz;
    float3x3 matO2T = float3x3(tangentOS, bitangentOS, normalOS);
    float3 smoothNormalTS;
    smoothNormalTS.x = IN.color.r;
    smoothNormalTS.y = IN.color.g;
    smoothNormalTS.z = sqrt(1 - dot(smoothNormalTS.xy, smoothNormalTS.xy));
    float3 smoothNormalOS = mul(smoothNormalTS, matO2T);

    // 物体空间的法线
    // smoothNormalOS = float3(IN.color.r, IN.color.g, IN.color.b);

    //计算法线从物体到裁切空间的矩阵 -> 计算裁切空间的法线
    float3 smoothNormalWS = TransformObjectToWorldNormal(smoothNormalOS);

    float3 smoothNormalCS = TransformWorldToHClipDir(smoothNormalWS); //法线转换到裁剪空间(齐次化前后法线不变,因为没有xy缩放)

    //计算均匀偏移量
    float2 extendDis = normalize(smoothNormalCS.xy) * _OutlineWidth; //根据法线和线宽计算偏移量
    //由于屏幕比例可能不是1:1，所以偏移量会被拉伸显示
    extendDis.x = extendDis.x / scaledScreenParams.x * scaledScreenParams.y; //根据屏幕比例进行拉伸x

    VertexPositionInputs positionInput = GetVertexPositionInputs(IN.positionOS.xyz);
    float4 positionHCS = positionInput.positionCS; //物体空间转换到裁剪空间

    //屏幕下描边宽度不变，则需要顶点偏移的距离在NDC坐标下为固定值
    //因为后续会转换成NDC坐标，会除w进行缩放，所以先乘一个w，那么该偏移的距离就不会在NDC下有变换
    positionHCS.xy += extendDis * positionHCS.w * weight; //根据偏移量进行偏移

    OUT.positionHCS = positionHCS;
    return OUT;
}
half4 outline_frag(VaryingsOutline1 IN) : SV_Target
{
    
    return 0;
}

#endif
