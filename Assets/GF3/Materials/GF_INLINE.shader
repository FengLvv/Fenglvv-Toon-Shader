Shader "3R2/GF/INLINE"
{
    Properties
    {
        [Toggle] _AdditionalLight ("Add light", Float) = 0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "Assets/MyMaterial/Repo/PBR.hlsl"
    //额外光照
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    //lightmap
    #pragma multi_compile _ LIGHTMAP_ON
    float _InlineWidth;
    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
float _LightAttenuation;
    
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
        float3 mainLightColor = lambert * mainLight.color * _LightAttenuation;

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

        float alpha = length(color)*_LightAttenuation;
        OUT = float4(color, alpha);
        return OUT;
    }
    ENDHLSL
    SubShader
    {
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Name "Inline"
            Tags
            {
                "LightMode"="Inline"
            }
            ZWrite Off
            ZTest Equal
            HLSLPROGRAM
            #pragma vertex inline_vert
            #pragma fragment inline_frag
            ENDHLSL
        }
    }
}