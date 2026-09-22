#ifndef IRIS_SPHERE_LIB_DATA_FLUID_ENCODING_GLSL
#define IRIS_SPHERE_LIB_DATA_FLUID_ENCODING_GLSL 1
#include "/lib/config/constants.glsl"

uint packFluidSurface(float height, vec2 downhill) {
    float slope = length(downhill);
    uint encodedHeading = 0u;

    if (slope > 1e-6)
        encodedHeading = uint(round(fract(atan(downhill.y, downhill.x) / TWO_PI + 1.0) * FLUID_HEADING_STEPS)) & FLUID_BYTE_MASK;

    uint encodedSpeed = uint(round(clamp(slope * FLOW_SLOPE_MULTIPLIER, 0.0, 1.0) * FLUID_SPEED_STEPS));
    uint encodedHeight = uint(clamp(round(height * FLUID_HEIGHT_SCALE) + 1.0, 1.0, FLUID_MAX_ENCODED_HEIGHT));

    return (encodedHeight << FLUID_HEIGHT_SHIFT) | (encodedHeading << FLUID_HEADING_SHIFT) | encodedSpeed;
}

float fluidSurfaceHeight(uint encodedSurface) {
    return (float(encodedSurface >> FLUID_HEIGHT_SHIFT) - 1.0) / FLUID_HEIGHT_SCALE;
}

vec2 fluidSurfaceCurrent(uint encodedSurface, float maximumSpeed) {
    float headingAngle = float((encodedSurface >> FLUID_HEADING_SHIFT) & FLUID_BYTE_MASK) * (TWO_PI / FLUID_HEADING_STEPS);
    float speed = float(encodedSurface & FLUID_BYTE_MASK) * (maximumSpeed / FLUID_SPEED_STEPS);
    return vec2(cos(headingAngle), sin(headingAngle)) * speed;
}

#endif
