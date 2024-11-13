#pragma once

#include <simd/simd.h>

struct UpdateGameOfLifeConfig
{
    simd_uint2 size;
    uint32_t updateCounter;
    float spawnProbability;
    float idleThreshold;
};

struct UpdateTrailConfig
{
    simd_uint2 lifeSize;
    simd_uint2 trailSize;
    float lifeDecay;
    float trailDecay;
    float trailSpread;
    uint32_t updateCounter;
};

struct VertexOut
{
    simd_float4 pos [[position]];
    simd_float2 texCoord;
};

struct RenderUniforms
{
    simd_uint2 lifeSize;
    simd_uint2 trailSize;
    simd_uint2 outputSize;
    float time;
    float interpolationFrac;
    float maxOutput;
    uint32_t updateCounter;
    simd_float3 color1;
    simd_float3 color2;
    simd_float3 color3;
    simd_float3 bgColor;
    int isInverted;
    int bleachBackground;
    float trailSamplingNoise;
    float activityMultiplier;
    float lifeStateMultiplier;
    float noiseSpeed;
    simd_float2 logoSize;
    float logoBorder;
    float logoBlending;
};
