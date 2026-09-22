#ifndef IRIS_SPHERE_LIB_CAPTURE_FLUID_FIELD_GLSL
#define IRIS_SPHERE_LIB_CAPTURE_FLUID_FIELD_GLSL 1
#include "/lib/data/fluid_encoding.glsl"

void captureFluidBoundary(vec3 triangleA, vec3 triangleB, vec3 triangleC, int mediumType, float upwardNormal) {

#if BUOYANCY_ENABLED == 1
    if (mediumType != MEDIUM_SOLID && upwardNormal < 0.5)
        return;

    vec3 triangleNormal = cross(triangleB - triangleA, triangleC - triangleA);

    if (abs(triangleNormal.y) < 1e-8)
        return;

    vec3 triangleBoundsMin = min(triangleA, min(triangleB, triangleC));
    vec3 triangleBoundsMax = max(triangleA, max(triangleB, triangleC));
    vec3 gridOrigin = fluidGridOrigin.xyz;

    if (triangleBoundsMax.y < gridOrigin.y || triangleBoundsMin.y >= gridOrigin.y + float(FLUID_LAYER_COUNT))
        return;

    ivec2 firstColumn = ivec2(ceil((triangleBoundsMin.xz - gridOrigin.xz) / FLUID_COLUMN_WIDTH - 0.5001));
    ivec2 lastColumn = ivec2(floor((triangleBoundsMax.xz - gridOrigin.xz) / FLUID_COLUMN_WIDTH - 0.4999));

    if (any(lessThan(lastColumn, ivec2(0))) || any(greaterThanEqual(firstColumn, ivec2(FLUID_GRID_SIZE))))
        return;

    firstColumn = clamp(firstColumn, ivec2(0), ivec2(FLUID_GRID_SIZE - 1));
    lastColumn = clamp(lastColumn, ivec2(0), ivec2(FLUID_GRID_SIZE - 1));

    vec2 edgeAB = triangleB.xz - triangleA.xz, edgeAC = triangleC.xz - triangleA.xz;
    float determinant = edgeAB.x * edgeAC.y - edgeAB.y * edgeAC.x;

    for (int columnZ = firstColumn.y; columnZ <= lastColumn.y; ++columnZ)
        for (int columnX = firstColumn.x; columnX <= lastColumn.x; ++columnX) {

            vec2 sampleOffset = gridOrigin.xz + (vec2(columnX, columnZ) + 0.5) * FLUID_COLUMN_WIDTH - triangleA.xz;
            float barycentricB = (sampleOffset.x * edgeAC.y - sampleOffset.y * edgeAC.x) / determinant;
            float barycentricC = (edgeAB.x * sampleOffset.y - edgeAB.y * sampleOffset.x) / determinant;

            if (barycentricB < -1e-5 || barycentricC < -1e-5 || barycentricB + barycentricC > 1.00001)
                continue;

            float height = triangleA.y + barycentricB * (triangleB.y - triangleA.y) + barycentricC * (triangleC.y - triangleA.y) - gridOrigin.y;
            int layerIndex = int(floor(height));

            if (layerIndex < 0 || layerIndex >= FLUID_LAYER_COUNT)
                continue;

            int cellIndex = columnX + FLUID_GRID_SIZE * columnZ + FLUID_GRID_SIZE * FLUID_GRID_SIZE * layerIndex;
            uint encodedHeight = floatBitsToUint(height + 1.0);

            if (mediumType == MEDIUM_WATER)
                atomicMax(fluidColumnLayers[cellIndex].x, packFluidSurface(height, triangleNormal.xz / triangleNormal.y));
            else if (mediumType == MEDIUM_LAVA)
                atomicMax(fluidColumnLayers[cellIndex].y, packFluidSurface(height, triangleNormal.xz / triangleNormal.y));
            else {
                atomicMin(fluidColumnLayers[cellIndex].z, encodedHeight);
                atomicMax(fluidColumnLayers[cellIndex].w, encodedHeight);
            }
        }
#endif
}

#endif
