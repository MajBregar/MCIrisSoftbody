#ifndef IRIS_SPHERE_LIB_CAPTURE_SHADOW_GEOMETRY_GLSL
#define IRIS_SPHERE_LIB_CAPTURE_SHADOW_GEOMETRY_GLSL 1
#include "/lib/common/uniforms.glsl"
#include "/lib/config/settings.glsl"
#include "/lib/data/buffers.glsl"
#include "/lib/capture/fluid_field.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;
in vec3 collisionPosition[];
flat in int collisionFluid[];
flat in int collisionBlockId[];
flat in float collisionNormalY[];

void main() {
    bool isEntity = false;
    bool isBlockEntity = false;

#ifdef MC_RENDER_STAGE_ENTITIES
    isEntity = isEntity || renderStage == MC_RENDER_STAGE_ENTITIES;
#endif

#ifdef MC_RENDER_STAGE_BLOCK_ENTITIES
    isBlockEntity = renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES;
    isEntity = isEntity || isBlockEntity;
#endif

    if (captureStatus.outsideSimulationRange != 0u)
        return;

    if (isBlockEntity && blockEntityId == MATERIAL_PASS_THROUGH)
        return;

    if (!isEntity && collisionBlockId[0] == MATERIAL_PASS_THROUGH && collisionFluid[0] == MEDIUM_SOLID)
        return;

    vec3 triangleA = collisionPosition[0], triangleB = collisionPosition[1], triangleC = collisionPosition[2];
    vec3 triangleBoundsMin = min(triangleA, min(triangleB, triangleC));
    vec3 triangleBoundsMax = max(triangleA, max(triangleB, triangleC));

    if (isEntity) {
#if ENTITY_COLLISIONS == 1 && COLLISION_ENABLED == 1
        ivec3 firstCell = ivec3(floor((triangleBoundsMin - entityGridOrigin.xyz) / ENTITY_CELL_SIZE));
        ivec3 lastCell = ivec3(floor((triangleBoundsMax - entityGridOrigin.xyz) / ENTITY_CELL_SIZE));

        if (any(lessThan(lastCell, ivec3(0))) || any(greaterThanEqual(firstCell, ivec3(ENTITY_GRID_SIZE))))
            return;

        firstCell = clamp(firstCell, ivec3(0), ivec3(ENTITY_GRID_SIZE - 1));
        lastCell = clamp(lastCell, ivec3(0), ivec3(ENTITY_GRID_SIZE - 1));

        uint occupiedRowMask = (1u << uint(lastCell.x - firstCell.x + 1)) - 1u;
        for (int cellZ = firstCell.z; cellZ <= lastCell.z; ++cellZ)
            for (int cellY = firstCell.y; cellY <= lastCell.y; ++cellY) {
                uint cellIndex = uint(firstCell.x + ENTITY_GRID_SIZE * (cellY + ENTITY_GRID_SIZE * cellZ));
                atomicOr(entityOccupancyWords[cellIndex >> OCCUPANCY_WORD_SHIFT], occupiedRowMask << (cellIndex & OCCUPANCY_BIT_MASK));
            }
#endif
        return;
    }

    captureFluidBoundary(triangleA, triangleB, triangleC, collisionFluid[0], collisionNormalY[0]);

    if (collisionFluid[0] != MEDIUM_SOLID)
        return;

    if (any(lessThan(triangleBoundsMax, captureBoundsMin.xyz)) || any(greaterThan(triangleBoundsMin, captureBoundsMax.xyz)) || length(cross(triangleB - triangleA, triangleC - triangleA)) < 1e-7)
        return;

    uint triangleIndex = atomicAdd(captureStatus.triangleCount, 1u);
    
    if (triangleIndex < uint(COLLIDER_CAPACITY)) {
        terrainTriangleVertices[triangleIndex * 3u] = vec4(triangleA, 0.0);
        terrainTriangleVertices[triangleIndex * 3u + 1u] = vec4(triangleB, 0.0);
        terrainTriangleVertices[triangleIndex * 3u + 2u] = vec4(triangleC, 0.0);
    } else
        atomicOr(captureStatus.overflow, 1u);
}

#endif
