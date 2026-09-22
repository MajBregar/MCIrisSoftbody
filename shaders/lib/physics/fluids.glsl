#ifndef IRIS_SPHERE_LIB_PHYSICS_FLUIDS_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_FLUIDS_GLSL 1

#include "/lib/data/fluid_encoding.glsl"

vec2 fluidAt(vec3 position, out vec2 currentVelocity) {
    currentVelocity = vec2(0.0);
#if BUOYANCY_ENABLED == 1
    vec3 gridPosition = position - fluidGridOrigin.xyz;
    ivec2 columnIndex = ivec2(floor(gridPosition.xz / FLUID_COLUMN_WIDTH));
    if (any(lessThan(columnIndex, ivec2(0))) || any(greaterThanEqual(columnIndex, ivec2(FLUID_GRID_SIZE))) ||
        gridPosition.y < 0.0 || gridPosition.y >= float(FLUID_LAYER_COUNT))
        return vec2(0.0);
    for (int layerIndex = int(floor(gridPosition.y)); layerIndex < FLUID_LAYER_COUNT; ++layerIndex) {
        uvec4 boundaries = fluidColumnLayers[columnIndex.x + FLUID_GRID_SIZE * columnIndex.y +
                                             FLUID_GRID_SIZE * FLUID_GRID_SIZE * layerIndex];
        float nearestHeight = 1e20;
        int mediumType = MEDIUM_SOLID;
        uint encodedSurface = 0u;
        float waterHeight = fluidSurfaceHeight(boundaries.x), lavaHeight = fluidSurfaceHeight(boundaries.y);
        if (boundaries.x != 0u && waterHeight >= gridPosition.y) {
            nearestHeight = waterHeight;
            mediumType = MEDIUM_WATER;
            encodedSurface = boundaries.x;
        }
        if (boundaries.y != 0u && lavaHeight >= gridPosition.y && lavaHeight < nearestHeight) {
            nearestHeight = lavaHeight;
            mediumType = MEDIUM_LAVA;
            encodedSurface = boundaries.y;
        }

        float minimumSolidHeight =
            boundaries.z == EMPTY_SOLID_BOUNDARY ? -1e20 : uintBitsToFloat(boundaries.z) - 1.0;
        float maximumSolidHeight = boundaries.w == 0u ? -1e20 : uintBitsToFloat(boundaries.w) - 1.0;
        if (minimumSolidHeight >= gridPosition.y &&
            minimumSolidHeight <= nearestHeight + FLUID_HEIGHT_TOLERANCE) {
            nearestHeight = minimumSolidHeight;
            mediumType = MEDIUM_SOLID;
        }
        if (maximumSolidHeight >= gridPosition.y &&
            maximumSolidHeight <= nearestHeight + FLUID_HEIGHT_TOLERANCE) {
            nearestHeight = maximumSolidHeight;
            mediumType = MEDIUM_SOLID;
        }
        if (nearestHeight < 1e19) {
            if (mediumType == MEDIUM_SOLID)
                return vec2(0.0);
#if FLUID_CURRENTS == 1
            currentVelocity = fluidSurfaceCurrent(
                encodedSurface, mediumType == MEDIUM_LAVA ? LAVA_CURRENT_SPEED : WATER_CURRENT_SPEED);
#endif
            float submersionDepth = nearestHeight - gridPosition.y;
            return vec2(smoothstep(0.0, FLUID_SURFACE_BLEND_DEPTH, submersionDepth),
                        mediumType == MEDIUM_LAVA ? LAVA_DRAG : WATER_DRAG);
        }
    }
#endif
    return vec2(0.0);
}

vec2 fluidAt(vec3 position) {
    vec2 unusedCurrent;
    return fluidAt(position, unusedCurrent);
}

#endif
