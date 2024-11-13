//
//  GameOfLife.metal
//  ConwayWatercolor
//
//  Created by Max Maton on 04/11/2024.
//

#include <metal_stdlib>
#include "ShaderDefs.h"

using namespace metal;

thread uint32_t randq1(uint32_t seed)
{
    return seed * 1664525 + 1013904223;
}

thread uint32_t randLFSR(uint32_t seed)
{
    uint32_t bit  = ((seed >> 0) ^ (seed >> 2) ^ (seed >> 3) ^ (seed >> 5)) & 1;
    uint32_t lfsr = (seed >> 1) | (bit << 31); // Shift right and insert feedback bit
    return lfsr;
}

thread uint32_t randLaunderBadSeed(uint32_t seed, uint32_t c)
{
    for (int i = 0; i < 2; i++) {
        seed = c ^ randq1(seed) ^ randLFSR(seed);
        c = randq1(c);
    }
    return seed;
}

thread float randFloat(uint32_t seed)
{
    uint32_t truncated = seed >> 16 ^ (seed & ((1 << 16) - 1));
    return (float)truncated / (1 << 16);
}

thread float4 rand3d(uint32_t x, uint32_t y, uint32_t z, uint32_t seed)
{
    uint32_t zSeed = randq1(z ^ seed);

    uint32_t posSeed1 = randLaunderBadSeed(x ^ y << 16, zSeed);
    uint32_t posSeed2 = randq1(posSeed1);
    uint32_t posSeed3 = randq1(posSeed2);
    uint32_t posSeed4 = randq1(posSeed3);
    
    return float4(randFloat(posSeed1), randFloat(posSeed2), randFloat(posSeed3), randFloat(posSeed4));
}

thread float4 rand3dInterp(float x, float y, float z, uint32_t seed)
{
    uint32_t baseX = floor(x);
    float fracX = fract(x);
    uint32_t baseY = floor(y);
    float fracY = fract(y);
    uint32_t baseZ = floor(z);
    float fracZ = fract(z);
    
    float4 resultX0Y0Z0 = rand3d(baseX, baseY, baseZ, seed);
    float4 resultX0Y0Z1 = rand3d(baseX, baseY, baseZ + 1, seed);
    float4 resultX0Y1Z0 = rand3d(baseX, baseY + 1, baseZ, seed);
    float4 resultX0Y1Z1 = rand3d(baseX, baseY + 1, baseZ + 1, seed);
    float4 resultX1Y0Z0 = rand3d(baseX + 1, baseY, baseZ, seed);
    float4 resultX1Y0Z1 = rand3d(baseX + 1, baseY, baseZ + 1, seed);
    float4 resultX1Y1Z0 = rand3d(baseX + 1, baseY + 1, baseZ, seed);
    float4 resultX1Y1Z1 = rand3d(baseX + 1, baseY + 1, baseZ + 1, seed);
    
    float4 resultX0Y0 = mix(resultX0Y0Z0, resultX0Y0Z1, fracZ);
    float4 resultX0Y1 = mix(resultX0Y1Z0, resultX0Y1Z1, fracZ);
    float4 resultX1Y0 = mix(resultX1Y0Z0, resultX1Y0Z1, fracZ);
    float4 resultX1Y1 = mix(resultX1Y1Z0, resultX1Y1Z1, fracZ);
    
    float4 resultX0 = mix(resultX0Y0, resultX0Y1, fracY);
    float4 resultX1 = mix(resultX1Y0, resultX1Y1, fracY);
    
    return mix(resultX0, resultX1, fracX);
}

kernel void updateGameOfLife(
                             texture2d<ushort, access::sample> prev [[texture(0)]],
                             texture2d<ushort, access::write> next [[texture(1)]],
                             texture2d<float, access::sample> trail [[texture(2)]],
                             constant UpdateGameOfLifeConfig &config [[buffer(0)]],
                             const uint2 position [[thread_position_in_grid]])
{
                                
    constexpr sampler textureSampler (mag_filter::nearest,
                                      min_filter::nearest,
                                      address::repeat,
                                      coord::normalized);
    
    float2 pixelSize = float2(1.0, 1.0) / (float2)config.size;
    float2 texCoord = pixelSize * ((float2)position + 0.5);

    ushort4 center = prev.sample(textureSampler, texCoord);
    
    ushort4 neighbors =
        prev.sample(textureSampler, texCoord + float2(-1, -1) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2( 0, -1) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2( 1, -1) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2(-1,  0) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2( 1,  0) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2(-1,  1) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2( 0,  1) * pixelSize) +
        prev.sample(textureSampler, texCoord + float2( 1,  1) * pixelSize)
        ;
    
    ushort4 result = ushort4(center.rgb, 0);
    
    if (center.r == 0) {
        if (neighbors.r == 3) {
            result.r = 1;
            result.a += 1;
        }
    } else {
        if (neighbors.r <= 1 || neighbors.r >= 4) {
            result.r = 0;
            result.a += 1;
        }
    }
    if (center.g == 0) {
        if (neighbors.g == 3) {
            result.g = 1;
            result.a += 1;
        }
    } else {
        if (neighbors.g <= 1 || neighbors.g >= 4) {
            result.g = 0;
            result.a += 1;
        }
    }
    if (center.b == 0) {
        if (neighbors.b == 3) {
            result.b = 1;
            result.a += 1;
        }
    } else {
        if (neighbors.b <= 1 || neighbors.b >= 4) {
            result.b = 0;
            result.a += 1;
        }
    }
    
    int gliderXDir = ((config.updateCounter / 2) % 2) * 2 - 1;
    int gliderYDir = (config.updateCounter % 2) * 2 - 1;
    
    float4 trailData = trail.sample(textureSampler, texCoord);
    if (trailData.a < config.idleThreshold) {
        float4 randDataMe = rand3d(position.x, position.y, config.updateCounter, 2287429796);
        float4 randDataLeft = rand3d(position.x + 1 * gliderXDir, position.y, config.updateCounter, 2287429796);
        float4 randDataTop = rand3d(position.x, position.y + 1 * gliderYDir, config.updateCounter, 2287429796);
        float4 randDataLeftLeft = rand3d(position.x + 2 * gliderXDir, position.y, config.updateCounter, 2287429796);
        float4 randDataDiag = rand3d(position.x + 1 * gliderXDir, position.y + 2 * gliderYDir, config.updateCounter, 2287429796);
        
        float chance = config.spawnProbability;
        
        if (randDataMe.a < chance)
        {
            result.a = 0;
            result.r = randDataMe.r < 0.5 ? 0.0 : 1.0;
            result.g = randDataMe.g < 0.5 ? 0.0 : 1.0;
            result.b = randDataMe.b < 0.5 ? 0.0 : 1.0;
        } else if (randDataLeft.a < chance)
        {
            result.a = 0;
            result.r = randDataLeft.r < 0.5 ? 0.0 : 1.0;
            result.g = randDataLeft.g < 0.5 ? 0.0 : 1.0;
            result.b = randDataLeft.b < 0.5 ? 0.0 : 1.0;
        } else if (randDataTop.a < chance)
        {
            result.a = 0;
            result.r = randDataTop.r < 0.5 ? 0.0 : 1.0;
            result.g = randDataTop.g < 0.5 ? 0.0 : 1.0;
            result.b = randDataTop.b < 0.5 ? 0.0 : 1.0;
        } else if (randDataLeftLeft.a < chance)
        {
            result.a = 0;
            result.r = randDataLeftLeft.r < 0.5 ? 0.0 : 1.0;
            result.g = randDataLeftLeft.g < 0.5 ? 0.0 : 1.0;
            result.b = randDataLeftLeft.b < 0.5 ? 0.0 : 1.0;
        } else if (randDataDiag.a < chance)
        {
            result.a = 0;
            result.r = randDataDiag.r < 0.5 ? 0.0 : 1.0;
            result.g = randDataDiag.g < 0.5 ? 0.0 : 1.0;
            result.b = randDataDiag.b < 0.5 ? 0.0 : 1.0;
        }
    }
    
    next.write(result, position);
}

kernel void resetTrails(texture2d<float, access::write> drawable   [[ texture(0) ]],
                            const uint2 position [[thread_position_in_grid]]) {
    
    drawable.write(float4(0.0, 0.0, 0.0, 0.0), position);
}

kernel void updateTrails(
                         texture2d<ushort, access::sample> lifePrevTexture   [[ texture(0) ]],
                         texture2d<ushort, access::sample> lifeNextTexture   [[ texture(1) ]],
                         texture2d<float, access::sample> trailPrevTexture   [[ texture(2) ]],
                         texture2d<float, access::write> trailNextTexture   [[ texture(3) ]],
                         constant UpdateTrailConfig &config [[buffer(0)]],
                         const uint2 position [[thread_position_in_grid]]
                         )
{
    constexpr sampler nearestSampler (mag_filter::nearest,
                                      min_filter::nearest,
                                      address::repeat,
                                      coord::normalized);
    
    float2 lifePixelSize = float2(1.0, 1.0) / (float2)config.lifeSize;
    float2 trailPixelSize = float2(1.0, 1.0) / (float2)config.trailSize;
    float2 trailTexCoord = trailPixelSize * ((float2)position + 0.5);
    
    float2 trailScale = (float2)config.trailSize / (float2)config.lifeSize;
    float2 lifeTexCoord = lifePixelSize * ((float2)position / trailScale + 0.5);

    ushort4 lifePrev = lifePrevTexture.sample(nearestSampler, lifeTexCoord);
    ushort4 lifeNext = lifeNextTexture.sample(nearestSampler, lifeTexCoord);
    short isActive = lifePrev.a >= 1 xor lifeNext.a >= 1;
    
    float4 prevTrail = trailPrevTexture.sample(nearestSampler, trailTexCoord);
    
    float4 neighTrail = max(
                            max(
                                max(
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2(-1,  0) * trailPixelSize),
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2( 1,  0) * trailPixelSize)
                                    ),
                                max(
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2( 0, -1) * trailPixelSize),
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2( 0,  1) * trailPixelSize)
                                    )
                                ),
                            max(
                                max(
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2(-1, -1) * trailPixelSize),
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2(-1,  1) * trailPixelSize)
                                    ),
                                max(
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2( 1, -1) * trailPixelSize),
        trailPrevTexture.sample(nearestSampler, trailTexCoord + float2( 1,  1) * trailPixelSize)
                                    )
                                )
                            );
    
    float4 result = 0;
    
    result.rgb = max(prevTrail.rgb - config.lifeDecay, (float3)lifeNext.rgb);
    result.a = max(0.0, max((float)isActive + config.trailSpread * neighTrail.a, prevTrail.a) - config.trailDecay);
    
    trailNextTexture.write(result, position);
}

vertex VertexOut renderScreensaverVertex(const device float2 *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    float2 input = vertexArray[vid];
    VertexOut result;
    
    result.pos = float4(input.x, input.y, 0, 1);
    result.texCoord = (input + 1.0) / 2.0;
    
    return result;
}

thread float4 stackedNoise(float x, float y, float z, uint32_t layer1Seed, uint32_t layer2Seed, uint32_t layer3Seed, float layer1Scale, float layer2Scale, float layer3Scale, float layer1Weight, float layer2Weight, float layer3Weight)
{
    float4 layer1Val = rand3dInterp(x * layer1Scale, y * layer1Scale, z * layer1Scale, layer1Seed);
    float4 layer2Val = rand3dInterp(x * layer2Scale, y * layer2Scale, z * layer2Scale, layer2Seed);
    float4 layer3Val = rand3dInterp(x * layer3Scale, y * layer3Scale, z * layer3Scale, layer3Seed);
    
    return layer1Val * layer1Weight + layer2Val * layer2Weight + layer3Val * layer3Weight;
}

float4 rgbToCymk(float3 rgb) {
    float k = 1 - max(max(rgb.r, rgb.g), rgb.b);
    float kinv = 1.0 - k;
    return float4((1.0 - rgb - k) / kinv, k);
}

float3 cymkToRgb(float4 cymk) {
    float kinv = 1.0 - cymk.a;
    return (1.0 - cymk.rgb) * kinv;
}

fragment float4 renderScreensaverFragment(
                                          VertexOut interpolated [[stage_in]],
                                          constant RenderUniforms &uniforms [[buffer(0)]],
                                          texture2d<ushort> prevGameOfLifeTexture [[texture(0)]],
                                          texture2d<ushort> nextGameOfLifeTexture [[texture(1)]],
                                          texture2d<float, access::sample> trailPrevTexture   [[ texture(2) ]],
                                          texture2d<float, access::sample> trailNextTexture   [[ texture(3) ]],
                                          texture2d<float, access::sample> logoTexture [[texture(4)]]
                                          )
{
    constexpr sampler textureSampler (mag_filter::nearest,
                                      min_filter::nearest,
                                      address::repeat,
                                      coord::normalized);
    constexpr sampler trailSampler (mag_filter::linear,
                                    min_filter::linear,
                                    address::repeat,
                                    coord::normalized);
    constexpr sampler logoSampler (mag_filter::bicubic,
                                   min_filter::bicubic,
                                   address::clamp_to_zero,
                                   coord::normalized);
    
    float2 trailPixelSize = float2(1.0, 1.0) / (float2)uniforms.trailSize;
    float2 outputPixelSize = float2(1.0, 1.0) / (float2)uniforms.outputSize;

    ushort4 prevLife = prevGameOfLifeTexture.sample(textureSampler, interpolated.texCoord);
    ushort4 nextLife = nextGameOfLifeTexture.sample(textureSampler, interpolated.texCoord);
    float4 interimLife = float4(max(prevLife, nextLife));
    
    float4 interpolatedLife;
    if (uniforms.interpolationFrac < 0.5) {
        interpolatedLife = mix((float4)prevLife, interimLife, uniforms.interpolationFrac * 2.0);
    } else {
        interpolatedLife = mix(interimLife, (float4)nextLife, uniforms.interpolationFrac * 2.0 - 1.0);
    }
    
    float z = (uniforms.updateCounter + uniforms.interpolationFrac) * uniforms.noiseSpeed;
    float4 randVal = stackedNoise(interpolated.texCoord.x * uniforms.outputSize.x, interpolated.texCoord.y * uniforms.outputSize.y, z, 4075602248, 2809798515, 2746737243, 1.0, 0.25, 0.0625, 0.1, 0.3, 0.6) * 2.0 - 1.0;
    
    float2 trailSampleCoord = interpolated.texCoord + randVal.xy * trailPixelSize * uniforms.trailSamplingNoise;
    
    float4 prevTrail = trailPrevTexture.sample(trailSampler, trailSampleCoord);
    float4 nextTrail = trailNextTexture.sample(trailSampler, trailSampleCoord);
    float4 interpolatedTrail = mix(prevTrail, nextTrail, uniforms.interpolationFrac);
    
    float4 maxValue = float4(uniforms.maxOutput, uniforms.maxOutput, uniforms.maxOutput, 1.0);
    
    float activity = mix(min(1.0, (float)prevLife.a), min(1.0, (float)nextLife.a), uniforms.interpolationFrac);

    float4 intermediate = min(maxValue, float4(mix(max(interpolatedTrail.rgb, -clamp(uniforms.lifeStateMultiplier, -1.0, 0.0) * interpolatedLife.rgb), interpolatedLife.rgb, clamp(uniforms.lifeStateMultiplier, 0.0, 1.0)), 1.0));
    
    float4 cymk1 = rgbToCymk(uniforms.isInverted ? 1.0 - uniforms.color1 : uniforms.color1);
    float4 cymk2 = rgbToCymk(uniforms.isInverted ? 1.0 - uniforms.color2 : uniforms.color2);
    float4 cymk3 = rgbToCymk(uniforms.isInverted ? 1.0 - uniforms.color3 : uniforms.color3);
    float4 bgCymk = rgbToCymk(uniforms.bgColor);
    
    float4 newColor = cymk1 * intermediate.r + cymk2 * intermediate.g + cymk3 * intermediate.b;
    if (uniforms.isInverted) {
        newColor = 1.0 - newColor;
    } else {
        newColor = newColor + bgCymk;
    }
    newColor = newColor;
    newColor.a -= activity * uniforms.activityMultiplier;
    newColor = clamp(newColor, 0.0, 1.0);
    if (uniforms.bleachBackground) {
        newColor -= bgCymk;
    }
    
    float2 logoBottomRight = float2(1, 0) + float2(-1.0, 1.0) * uniforms.logoBorder * outputPixelSize;
    float2 logoTopLeft = logoBottomRight + float2(-1.0, 1.0) * uniforms.logoSize * outputPixelSize;
    
    bool shouldRenderLogo =
        abs(uniforms.logoBlending) > 0.01 &&
        interpolated.texCoord.x >= logoTopLeft.x &&
        interpolated.texCoord.y < logoTopLeft.y &&
        interpolated.texCoord.x < logoBottomRight.x &&
        interpolated.texCoord.y > logoBottomRight.y;
    
    float2 logoTexcoords = 0;
    float4 logoSample = 0;
    if (shouldRenderLogo) {
        logoTexcoords = (interpolated.texCoord - logoTopLeft) / (logoBottomRight - logoTopLeft);
        logoSample = logoTexture.sample(logoSampler, logoTexcoords);
        
        float4 logoCymk = clamp(rgbToCymk(logoSample.rgb), 0.0, 1.0);
        if (uniforms.logoBlending < 0 && logoSample.a > 0.05) {
            float darkenAmount = 1.0 - (clamp(-uniforms.logoBlending, 0.3, 1.0) - 0.3) / 0.7;
            float mixAmount = 1.0 - clamp(-uniforms.logoBlending, 0.0, .7) / 0.7;
            
            //return float4(darkenAmount + mixAmount, darkenAmount + mixAmount, darkenAmount + mixAmount, 1.0);
            
            newColor += darkenAmount * logoCymk;
            
            newColor = mix(newColor, logoCymk, logoSample.a * mixAmount);
        }
    }
    
    float3 result = cymkToRgb(newColor);
    
    if (shouldRenderLogo && uniforms.logoBlending > 0) {
        result.rgb = mix(result.rgb, logoSample.rgb, logoSample.a * uniforms.logoBlending);
    }
    
    return float4(result, 1.0);
}
