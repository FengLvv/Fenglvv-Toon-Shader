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
        float4 color : COLOR;
        float3 normalOS : NORMAL;
    };

    struct VaryingsInline {
        float4 positionHCS : SV_POSITION;
        float3 positionVS : TEXCOORD0;
        float3 positionWS : TEXCOORD2;
        float3 normalWS : NORMAL;
         float4 color : COLOR;
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
        OUT.color = IN.color;
        return OUT;
    }

    half4 inline_frag(VaryingsInline IN) : SV_Target
    {
        float4 color = float4(IN.color.xyz,1);
        return color;
    }
    ENDHLSL
    SubShader
    {
        Pass
        {        
            ZWrite On
            ZTest LEqual
            HLSLPROGRAM
            #pragma vertex inline_vert
            #pragma fragment inline_frag
            ENDHLSL
        }
    }
}