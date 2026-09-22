#ifndef IRIS_SPHERE_LIB_DATA_BUFFERS_GLSL
#define IRIS_SPHERE_LIB_DATA_BUFFERS_GLSL 1
#include "/lib/config/constants.glsl"
#include "/lib/data/mesh_info.glsl"

struct CaptureStatus {
    uint triangleCount;
    uint overflow;
    uint outsideSimulationRange;
    uint numericalFault;
};

layout(std430, binding = 0) buffer TerrainColliders {
    CaptureStatus captureStatus;
    vec4 captureBoundsMin;
    vec4 captureBoundsMax;
    vec4 terrainTriangleVertices[COLLIDER_CAPACITY * 3];
};

layout(std430, binding = 1) buffer SphereParticles {
    vec4 particlePositions[VERTEX_COUNT]; // xyz position; w: -1 reset, 0 free, 1 contact
    vec4 particleNormals[VERTEX_COUNT];
    vec4 meshBoundsMin;
    vec4 meshBoundsMax;
    vec4 particleVelocities[VERTEX_COUNT]; // xyz velocity; w inverse mass
    vec4 solverClock;                      // remainder, elapsed simulation time, step count, reserved
    vec4 previousTetherTarget;
};

layout(std430, binding = 2) buffer EntityProximity {
    vec4 entityGridOrigin;
    uint entityOccupancyWords[ENTITY_GRID_WORDS];
};

layout(std430, binding = 3) buffer FluidField {
    vec4 fluidGridOrigin;
    uvec4 fluidColumnLayers[FLUID_CELL_COUNT]; // water, lava, solid min/max height
};

#endif
