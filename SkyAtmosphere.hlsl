#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#pragma region Variable
TEXTURE2D(_MainTex);
TEXTURE2D(_Source_RT);
TEXTURE2D_X_FLOAT(_CameraDepthTexture);         SAMPLER(sampler_CameraDepthTexture);

float4 _MainTex_TexelSize;
float4 _RTSize;

float4 _MainLightDir;
float _PlanetRadius;
float _SkyAtmosphereHeight;
float _SeaLevelHeight_R;        // H
float _SeaLevelHeight_M;
float4 _Extinction_R;            // 散射系数(瑞利散射)
float4 _Extinction_M;            // 散射系数(米氏散射)
float _MieG;                    // 米氏散射相位函数相关
float4 _Scattering_R;             // 散射方程前两项
float4 _Scattering_M;
float3 _LightColor;             // 初始光亮
float _DistanceScale;
int   _SampleCounts;

SamplerState sampler_LinearClamp;
SamplerState sampler_PointClamp;

struct VSInput
{
    float2 uv : TEXCOORD0;
    
    float4 positionOS : POSITION;
};

struct PSInput
{
    float2 uv : TEXCOORD0;

    float4 positionCS : SV_POSITION;
};

struct PSOutput
{
    float4 color : SV_TARGET;
};

#pragma endregion

#pragma region Tool
float Pow2(float i)
{
    return i * i;
}
#pragma endregion 

#pragma region Rebuild_Pos_WS
PSInput ReBuildPositionWSVS(VSInput i)
{
    PSInput o = (PSInput)0;

    VertexPositionInputs vertexPosData = GetVertexPositionInputs(i.positionOS);
    o.positionCS = vertexPosData.positionCS;

    o.uv = i.uv;
    #if defined (UNITY_UV_STARTS_AT_TOP)
        if(_MainTex_TexelSize.y < 0.f) o.uv.y = 1 - o.uv.y;
    #endif

    return o;
}

float3 ReBuildPosWS(float2 positionVP, float depth)
{
    ////////////////////
    // 变换到 NDC space
    ////////////////////
    float3 positionNDC = float3(positionVP * 2.f - 1.f, depth);
    #if defined (UNITY_UV_STARTS_AT_TOP)
    positionNDC.y = - positionNDC.y;
    #endif

    ////////////////////
    // 变换到 world space
    ////////////////////
    float4 positionWS = mul(UNITY_MATRIX_I_VP, float4(positionNDC, 1.f));
    positionWS.xyz /= positionWS.w;

    return positionWS;
}

PSOutput  ReBuildPositionWSPS(PSInput i)
{
    PSOutput o = (PSOutput)0;
    
    ////////////////////
    // 获取[0, 1]的viewport position
    ////////////////////
    float2 positionVP = (i.positionCS.xy - 0.5f) * _RTSize.zw;

    ////////////////////
    // 获取 depth
    ////////////////////
    float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, positionVP);

    float3 positionWS = ReBuildPosWS(positionVP, depth);

    o.color = float4(positionWS, 1.f);
    
    return o;
}
#pragma endregion

#pragma region SkyAtmosphere
PSInput SkyAtmosphere_VS(VSInput i)
{
    PSInput o = (PSInput)0;

    VertexPositionInputs vertexPosData = GetVertexPositionInputs(i.positionOS);
    o.positionCS = vertexPosData.positionCS;

    o.uv = i.uv;
    #if defined (UNITY_UV_STARTS_AT_TOP)
        if(_MainTex_TexelSize.y < 0.f) o.uv.y = 1 - o.uv.y;
    #endif

    return o;
}

/// ------------------ In
// rayOrigin    : 相机位置
// rayDir       : 相机朝向
// sphereCenter : 球体中心点
// sphereRadius : 球体半径

/// ------------------ Out
// return       : rayLength
float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float3 sphereRadius)
{
    float3 oc = rayOrigin - sphereCenter;

    float a = dot(rayDir, rayDir);
    float b = 2.f * dot(rayOrigin, oc);
    float c = dot(oc, oc) - Pow2(sphereRadius);
    float delta = Pow2(b) - 4 * a * c;

    if(delta < 0.f)
    {
        return -1.f;
    }
    else
    {
        return float2(-b - sqrt(delta), -b + sqrt(delta)) * rcp(2 * a);
    }
}

/// ------------------ In
//  currPos     :   采样点P
//  lightDir    :   光源方向

/// ------------------ Out
//  opticalDepthCP  : CP的光学深度
void LightSampling(float3 currPos, float3 lightDir, float3 planetCenter,
    inout float2 opticalDepthCP)
{
    float3 rayOrigin = currPos;
    float3 rayDir    = -lightDir;

    float2 intersection = RaySphereIntersection(rayOrigin, rayDir, planetCenter, _PlanetRadius + _SkyAtmosphereHeight);
    float3 rayEnd = rayOrigin + rayDir * intersection.y;

    float stepCount = 50;
    float3 step = (rayEnd - rayOrigin) / _SampleCounts;
    float stepLength = length(step);
    float2 density = 0;

    for(float s = 0.5; s < _SampleCounts; ++s)
    {
        float3 pos   = rayOrigin + step * s;
        float height = abs(length(pos - planetCenter) - _PlanetRadius);
        float2 currDensity = exp(-(height.xx / float2(_SeaLevelHeight_R, _SeaLevelHeight_M)));

        density += currDensity * stepLength;
    }

    opticalDepthCP = density;
}

/// ------------------ In
//  currPos     :   采样点P
//  lightDir    :   光源方向

/// ------------------ Out
//  opticalDepth CP & opticalDepth PA
void GetAtmosphereOpticalDepth(float3 currPos, float3 lightDir, float3 planetCenter,
    inout float2 dpa, inout float2 dpc)
{
    float height = length(currPos - planetCenter) - _PlanetRadius;
    dpa = exp(- height.xx / float2(_SeaLevelHeight_R, _SeaLevelHeight_M));

    //LightSampling(currPos, lightDir, planetCenter, dpc);
}

/// ------------------ In
//  localDensity :    rho(h)

/// ------------------ Out
//  localInscatter_R : 瑞利散射相关
//  localInscatter_M : 米氏散射相关
void CalcLocalInscatter(float2 localDensity, float2 D_PA, float2 D_CP,
    inout float3 localInscatter_R, inout float3 localInscatter_M)
{
    float2 D_CPA = D_PA + D_CP;

    float3 T_R = D_CPA.x * _Extinction_R;
    float3 T_M = D_CPA.y * _Extinction_M;

    float3 extinction = exp(-(T_M + T_R));

    localInscatter_R = localDensity.x * extinction;
    localInscatter_M = localDensity.y * extinction;
}

/// ------------------ In
//  cosAngle : 散射角

/// ------------------ Out
//  scatter_R : 乘上瑞丽相位函数
//  scatter_M : 乘上米氏相位函数
void GetPhaseFun(float cosAngle,
    inout float3 scatter_R, inout float3 scatter_M)
{
    float phase = 3.f * rcp(16.f * PI) * (1.f + Pow2(cosAngle));
    scatter_R  *= phase;

    float g   = _MieG;
    float g2  = Pow2(g);
    phase     = rcp(4.f * PI) * 3.f * (1.f - g2) * rcp(2.f * (2.f + g2)) * (1.f + Pow2(cosAngle)) * rcp(pow(1.f + g2 - 2 * g * cosAngle, 1.5f));
    scatter_M *= phase;
}


/// ------------------ In
//  rayOrigin     : 相机位置
//  rayDir        : 相机朝向
//  rayLength     : AB长度
//  planetCenter  : 地球中心位置
//  lightDir      : 光源方向
//  sampleCounts  : AB采样次数
//  distanceScale : 世界坐标尺寸

/// ------------------ Out
//  intensity   :   散射后的能量
//  extinction  :   透射率
void CalcSkyAtmosphereIntensity(float3 rayOrigin, float3 rayDir, float rayLength, float3 planetCenter, float3 lightDir, float sampleCounts, float distanceScale,
    inout float4 intensity, inout float4 extinction)
{
    // 步进信息
    float3 step = rayDir * (rayLength / sampleCounts);
    float stepLength = length(step) * distanceScale;

    float2 D_PA = 0;
    float3 scatter_R = 0;
    float3 scatter_M = 0;

    float2 localDensity = 0;
    float2 D_CP = 0;

    float2 preLocalDensity = 0;
    float3 preLocalInscatter_R, preLocalInscatter_M = 0;

    GetAtmosphereOpticalDepth(rayOrigin, lightDir, planetCenter, preLocalDensity, D_CP);
    CalcLocalInscatter(preLocalDensity, D_PA, D_CP, preLocalInscatter_R, preLocalInscatter_M);

    [loop]
    for(float i = 1; i < sampleCounts; ++i)
    {
        float3 currPos = rayOrigin + i * step;

        GetAtmosphereOpticalDepth(currPos, lightDir, planetCenter, localDensity, D_CP);
        D_PA += (localDensity + preLocalDensity) * (stepLength / 2.f);
        float3 localInscatter_R, localInscatter_M = 0;
        CalcLocalInscatter(localDensity, D_PA, D_CP, localInscatter_R, localInscatter_M);

        scatter_R += (localInscatter_R + preLocalInscatter_R) * (stepLength / 2.f);
        scatter_M += (localInscatter_M + preLocalInscatter_M) * (stepLength / 2.f);

        preLocalInscatter_R = localInscatter_R;
        preLocalInscatter_M = localInscatter_M;

        preLocalDensity = localDensity;
    }

    GetPhaseFun(dot(rayDir, -lightDir), scatter_R, scatter_M);
    
    intensity  = float4((scatter_R * _Scattering_R + scatter_M * _Scattering_M) * _LightColor, 1.f);
    extinction = exp(-(D_CP.x * _Extinction_R + D_CP.y * _Extinction_M));
    extinction.w = 0.f;
}


PSOutput SkyAtmosphere_PS(PSInput i)
{
    PSOutput o = (PSOutput)0;

    float2 uv    = (i.positionCS.xy - 0.5f) * _RTSize.zw;
    float deviceDepth  = _CameraDepthTexture.SampleLevel(sampler_LinearClamp, uv, 0).r;
    float3 posWS = ReBuildPosWS(uv, deviceDepth);
    
    float3 rayOrigin = GetCameraPositionWS();
    float3 rayDir    = posWS - rayOrigin;
    float  rayLength = length(rayDir);
    rayDir          /= rayLength;
    float3 planetCenter = float3(0, -_PlanetRadius, 0);

    if(deviceDepth < 0.000001f)
    {
        rayLength = 1e20;
    }
    
    float2 intersection = RaySphereIntersection(rayOrigin, rayDir, planetCenter, _PlanetRadius + _SkyAtmosphereHeight);

    rayLength = min(rayLength, intersection.y);

    intersection = RaySphereIntersection(rayOrigin, rayDir, planetCenter, _PlanetRadius);
    if(intersection.x > 0) rayLength = min(rayLength, intersection.x);

    float4 skyAtmosphereExtinction = 0;  // 大气透射积分
    float4 skyAtmosphereIntensity = 0;
    if(deviceDepth < 0.000001f)
    {
        CalcSkyAtmosphereIntensity(rayOrigin, rayDir, rayLength, planetCenter, _MainLightDir, _SampleCounts, _DistanceScale, skyAtmosphereIntensity, skyAtmosphereExtinction);
    }
    
    o.color = skyAtmosphereIntensity + _Source_RT.SampleLevel(sampler_LinearClamp, uv, 0);
    //o.color = float4(posWS, 1.f);
    return o;
}

#pragma endregion 