Shader "3R2/GF/EYE"
{
    Properties
    {
        //贴图
        [Header(Texture)]
        [MainTexture] [NoScaleOffset] _BaseMap ("Texture", 2D) = "white" {}
        
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend ("SrcBlend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend ("DstBlend", Float) = 0
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _SHADOWS_SOFT
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    //贴图
    TEXTURE2D(_BaseMap);
    SAMPLER(sampler_BaseMap);
    TEXTURE2D(_FaceSDFMap);
    SAMPLER(sampler_FaceSDFMap);


    CBUFFER_START(UnityPerMaterial)
    CBUFFER_END

    struct Attributes {
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
         float3 normalOS : NORMAL;
    };

    struct Varyings {
        float4 positionCS : SV_POSITION;
        float3 normalWS : NORMAL;
        float2 uv : TEXCOORD0;
        float4 shadowCoord : TEXCOORD4;        
    };

    Varyings vert(Attributes IN)
    {
        Varyings OUT;
        VertexPositionInputs vertices = GetVertexPositionInputs(IN.positionOS.xyz);
        OUT.uv = IN.uv;
        OUT.positionCS=vertices.positionCS;
        OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
        //阴影
        OUT.shadowCoord = TransformWorldToShadowCoord(vertices.positionWS.xyz);
        return OUT;
    }

    half4 frag(Varyings IN) : SV_Target
    {
        //光照参数
        Light mainLight = GetMainLight();
        float lightAttenuation = mainLight.shadowAttenuation;
        float3 lightDir = mainLight.direction;
        float3 lightColor = mainLight.color;

        float halfLambert=dot(lightDir,IN.normalWS)*0.5+0.5;
        //贴图
        half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
        half4 color;
        color.xyz =  baseMap.xyz*halfLambert*lightAttenuation;
        color.w = baseMap.w;  
    
        //阴影
        return float4(color);
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
            Blend [_SrcBlend] [_DstBlend]
            ZTest LEqual
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}