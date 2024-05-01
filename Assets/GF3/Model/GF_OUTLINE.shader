Shader "3R2/GF/OUTLINE"
{

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "Assets/MyMaterial/Repo/PBR.hlsl"
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"


    float _OutlineWidth;

        float4 _OutlineCol;

    struct AttributeOutline {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float4 color : COLOR;
        float4 tangentOS : TANGENT;
    };

    struct VaryingsOutline {
        float4 positionHCS : SV_POSITION;
        float3 positionVS : TEXCOORD0;
    };

    VaryingsOutline outline_vert(AttributeOutline IN)
    {
        float4 scaledScreenParams = GetScaledScreenParams();
        VaryingsOutline OUT;
        float weight = IN.color.a*4; //以后放到color.b

        // 处理tangent空间的法线
        float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
        float3 tangentWS = TransformObjectToWorldDir(IN.tangentOS.xyz);
        float3 bitangentWS = normalize(cross(normalWS, tangentWS) * IN.tangentOS.w);

        float3x3 matW2T = float3x3(tangentWS, bitangentWS, normalWS);
        float3 smoothNormalTS = normalize(IN.color.xyz);

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
        half4 color = lerp(_OutlineCol, _OutlineCol, -IN.positionVS.z * 0.1);
        return color;
    }
    ENDHLSL
    SubShader
    {
        Pass
        {
            Name "Outline"
            Tags
            {
                "LightMode"="Outline"
            }
            Cull Front
            ZWrite Off
            ZTest LEqual
            HLSLPROGRAM
            #pragma vertex outline_vert
            #pragma fragment outline_frag
            ENDHLSL
        }
    }
}