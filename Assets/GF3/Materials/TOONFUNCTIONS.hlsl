#ifndef _TOONFUNCTIONS
#define _TOONFUNCTIONS
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Assets/MyMaterial/Repo/PBR.hlsl"
#include "Assets/MyMaterial/Repo/MYTOONSHADER.hlsl"

real3 reverseACES(float3 color)
{
    return 3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
}



#endif
