#ifndef MYTOONSHADER
#define MYTOONSHADER

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

/**************************************顶点着色器外描边****************************************************/

//均匀描边
float4 createEvenOutlineInVert(float4 positionOS, float outlineWidth, float outlineWeight, float3 smoothNormalWS)
{
    float4 scaledScreenParams = GetScaledScreenParams();

    //计算法线从物体到裁切空间的矩阵 -> 计算裁切空间的法线
    float3 normalCS = TransformWorldToHClipDir(smoothNormalWS); //法线转换到裁剪空间(齐次化前后法线不变,因为没有xy缩放)

    //计算均匀偏移量
    float2 extendDis = normalize(normalCS.xy) * outlineWidth; //根据法线和线宽计算偏移量
    //由于屏幕比例可能不是1:1，所以偏移量会被拉伸显示
    extendDis.x = extendDis.x / scaledScreenParams.x * scaledScreenParams.y; //根据屏幕比例进行拉伸x
    //获取描边权重
    extendDis *= outlineWeight; //根据权重进行描边缩放

    VertexPositionInputs positionInput = GetVertexPositionInputs(positionOS.xyz);
    float4 positionHCS = positionInput.positionCS; //物体空间转换到裁剪空间

    //屏幕下描边宽度不变，则需要顶点偏移的距离在NDC坐标下为固定值
    //因为后续会转换成NDC坐标，会除w进行缩放，所以先乘一个w，那么该偏移的距离就不会在NDC下有变换
    positionHCS.xy += extendDis * positionHCS.w;

    return positionHCS;
}

//随屏幕距离变化的描边
float4 createChangedOutlineInVert(float4 positionOS, float farOutlineWidth, float outlineWeight, float maxOutLine, float3 smoothNormalWS)
{
    float4 scaledScreenParams = GetScaledScreenParams();

    //计算法线从物体到裁切空间的矩阵 -> 计算裁切空间的法线
    float3 normalCS = TransformWorldToHClipDir(smoothNormalWS); //法线转换到裁剪空间(齐次化前后法线不变,因为没有xy缩放)

    //计算裁切空间顶点
    VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS.xyz);
    float4 positionHCS = vertexInput.positionCS;

    farOutlineWidth*=outlineWeight;
    maxOutLine *= outlineWeight*positionHCS.w;
    float finalWidth = min(farOutlineWidth, maxOutLine);
    
    //计算均匀偏移量
    float2 extendDis = normalize(normalCS.xy) * finalWidth;                      //根据法线和线宽计算偏移量
    //由于屏幕比例可能不是1:1，所以偏移量会被拉伸显示
    extendDis.x = extendDis.x / scaledScreenParams.x * scaledScreenParams.y; //根据屏幕比例进行拉伸x

    //屏幕下描边宽度会变
    //齐次变化会把extendDis除以vertexCS.w（vertexVS.z)，和距离有关。如果不预先乘w，那么在NDC坐标下，会除以w，导致偏移量会变化
    //extendDis会随positionHCS.w变化， maxOutLine * positionHCS.w是最大偏移量，固定值
  
    positionHCS.xy += extendDis;

    return positionHCS;
}

/**************************************计算多阶兰伯特光照****************************************************/
half get3StepsLambert(half halfLambert, half lightThreashold, half shadowThreashold, out half lightArea, out half middleArea, out half darkArea)
{
    half step1 = step(lightThreashold, halfLambert);
    half step2 = step(shadowThreashold, halfLambert);
    lightArea = step1;
    middleArea = step2 - step1;
    darkArea = 1 - step2;
    return (step1 + step2) / 2;
}

half get3StepsLambert(half halfLambert, half lightThreashold, half shadowThreashold)
{
    half step1 = step(lightThreashold, halfLambert);
    half step2 = step(shadowThreashold, halfLambert);
    return (step1 + step2) / 2;
}

half get4StepsLambert(half halfLambert, half lightThreashold, half middleThreashold, half shadowThreashold)
{
    half step1 = step(lightThreashold, halfLambert);
    half step2 = step(middleThreashold, halfLambert);
    half step3 = step(shadowThreashold, halfLambert);
    return (step1 + step2 + step3) / 3;
}

half get4StepsLambert(half halfLambert, half lightThreashold, half middleThreashold, half shadowThreashold, out half lightArea, out half middleArea1, out half middleArea2, out half darkArea)
{
    half step1 = step(lightThreashold, halfLambert);
    half step2 = step(middleThreashold, halfLambert);
    half step3 = step(shadowThreashold, halfLambert);
    lightArea = step1;
    middleArea1 = step2 - step1;
    middleArea2 = step3 - step2;
    darkArea = 1 - step3;
    return (step1 + step2 + step3) / 3;
}

/**************************************采样SDF****************************************************/
float3 sampleSDF(Texture2D SDF, SamplerState sdfSampler, float2 uv, float3 lightDirWS, float3 normalWS, float3 forwardDirWS, float3 leftWS)
{
    //删除光向、前向的y数据
    float3 lightDirH = normalize(float3(lightDirWS.x, 0, lightDirWS.z));
    float3 forwardVec = normalize(float3(forwardDirWS.x, 0, forwardDirWS.z));
    //判断光向和前向的夹角，转成（0，1）【这里因为SDF是0-1的】
    float lightAtten = 1 - (dot(lightDirH, forwardVec) * 0.5 + 0.5);
    //光在左边取1，光在右边取-1
    float filpU = dot(lightDirH, leftWS) > 0 ? -1 : 1;
    //用uv采样SDF
    float3 rampTexSample = SAMPLE_TEXTURE2D(SDF, sdfSampler, uv * float2(filpU, 1)).xyz;
    //用SDF的采样结果STEP半兰伯特
    return step(lightAtten, rampTexSample);
}
float3 sampleSDFNose(Texture2D SDF, SamplerState sdfSampler, float2 uv, float3 lightDirWS, float3 normalWS, float3 forwardDirWS, float3 leftWS)
{
    //删除光向、前向的y数据
    float3 lightDirH = normalize(float3(lightDirWS.x, 0, lightDirWS.z));
    float3 forwardVec = normalize(float3(forwardDirWS.x, 0, forwardDirWS.z));
    //判断光向和前向的夹角，转成（0，1）【这里因为SDF是0-1的】
    float lightAtten = (dot(lightDirH, forwardVec));
    lightAtten = lightAtten < 0.001 ? 1 : lightAtten;
    //光在左边取1，光在右边取-1
    float filpU = dot(lightDirH, leftWS) > 0 ? -1 : 1;
    //用uv采样SDF
    float3 rampTexSample = SAMPLE_TEXTURE2D(SDF, sdfSampler, uv * float2(filpU, 1)).xyz;
    //用SDF的采样结果STEP半兰伯特
    return step(lightAtten, rampTexSample);
}

/**************************************预制的结构体****************************************************/
struct AttributeOutline {
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
    float4 tangentOS : TANGENT;
};

struct VaryingsOutline {
    float4 positionHCS : SV_POSITION;
    float3 positionVS  : TEXCOORD0;
};



#endif
