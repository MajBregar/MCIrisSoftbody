#ifndef IRIS_SPHERE_LIB_PASSES_INITIALIZE_GLSL
#define IRIS_SPHERE_LIB_PASSES_INITIALIZE_GLSL 1
#include "/lib/data/buffers.glsl"

layout(local_size_x = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main() {
    captureStatus = CaptureStatus(0u, 0u, 0u, 0u);
    entityGridOrigin = vec4(0.0);
    fluidGridOrigin = vec4(0.0);

    for (int particleIndex = 0; particleIndex < FLUID_CELL_COUNT; ++particleIndex)
        fluidColumnLayers[particleIndex] = uvec4(0u, 0u, EMPTY_SOLID_BOUNDARY, 0u);

    for (int particleIndex = 0; particleIndex < ENTITY_GRID_WORDS; ++particleIndex)
        entityOccupancyWords[particleIndex] = 0u;

    captureBoundsMin = captureBoundsMax = meshBoundsMin = meshBoundsMax = vec4(0.0);
    solverClock = previousTetherTarget = vec4(0.0);
    
    for (int particleIndex = 0; particleIndex < VERTEX_COUNT; ++particleIndex) {
        particlePositions[particleIndex] = vec4(0.0, 0.0, 0.0, -1.0);
        particleNormals[particleIndex] = vec4(0.0, 1.0, 0.0, 0.0);
        particleVelocities[particleIndex] = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

#endif
