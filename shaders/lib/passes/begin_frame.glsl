#ifndef IRIS_SPHERE_LIB_PASSES_BEGIN_FRAME_GLSL
#define IRIS_SPHERE_LIB_PASSES_BEGIN_FRAME_GLSL 1
#include "/lib/config/settings.glsl"
#include "/lib/data/buffers.glsl"
#include "/lib/physics/target.glsl"

layout(local_size_x = CAPTURE_WORKGROUP_SIZE) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main() {
    uint laneIndex = gl_LocalInvocationID.x;

    if (laneIndex == 0u) {
        vec3 bodyCenter = vec3(0.0);
        vec3 captureMinimum = vec3(1e20), captureMaximum = vec3(-1e20);

        for (int particleIndex = 0; particleIndex < VERTEX_COUNT; ++particleIndex) {
            vec3 targetParticlePosition = targetPosition(particleIndex);
            vec3 previousPosition = needsReset(particleIndex) 
                ? targetParticlePosition
                : particlePositions[particleIndex].xyz + previousCameraPosition - cameraPosition;

            bodyCenter += previousPosition / float(VERTEX_COUNT);
            vec3 predictedPosition = previousPosition + (needsReset(particleIndex) ? initialVelocity() : particleVelocities[particleIndex].xyz) * (float(MAX_PHYSICS_SUBSTEPS) * PHYSICS_TIMESTEP);

#if BALL_MODE == 1 || GRAB_ENABLED == 0
            targetParticlePosition = previousPosition;
#endif
            captureMinimum = min(captureMinimum, min(predictedPosition, min(previousPosition, targetParticlePosition)));
            captureMaximum = max(captureMaximum, max(predictedPosition, max(previousPosition, targetParticlePosition)));
        }

        float padding = CAPTURE_PADDING + CONTACT_MARGIN;
        entityGridOrigin = vec4(floor((bodyCenter + cameraPosition) / ENTITY_CELL_SIZE) * ENTITY_CELL_SIZE - cameraPosition - vec3(ENTITY_CELL_SIZE * float(ENTITY_GRID_SIZE) * 0.5), 0.0);
        fluidGridOrigin = vec4(floor(bodyCenter + cameraPosition) - cameraPosition - vec3(FLUID_GRID_LOWER_OFFSET), 0.0);
        captureBoundsMin = vec4(captureMinimum - padding, 0.0);
        captureBoundsMax = vec4(captureMaximum + padding, 0.0);
        bool outsideSimulationRange = length(bodyCenter) > SIMULATION_DISTANCE;
        captureStatus = CaptureStatus(0u, 0u, outsideSimulationRange ? 1u : 0u, 0u);

    }

    memoryBarrierBuffer();
    barrier();

    for (uint wordIndex = laneIndex; wordIndex < uint(ENTITY_GRID_WORDS); wordIndex += uint(CAPTURE_WORKGROUP_SIZE))
        entityOccupancyWords[wordIndex] = 0u;

    for (uint wordIndex = laneIndex; wordIndex < uint(FLUID_CELL_COUNT); wordIndex += uint(CAPTURE_WORKGROUP_SIZE))
        fluidColumnLayers[wordIndex] = uvec4(0u, 0u, EMPTY_SOLID_BOUNDARY, 0u);
}

#endif
