#ifndef IRIS_SPHERE_LIB_PHYSICS_ENTITIES_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_ENTITIES_GLSL 1

vec4 entityRepulsion(vec3 center) {
    vec4 deepestContact = vec4(0.0);
#if ENTITY_COLLISIONS == 1 && COLLISION_ENABLED == 1
    float separationRadius = SPHERE_RADIUS + ENTITY_CLEARANCE;
    for (uint wordIndex = 0u; wordIndex < uint(ENTITY_GRID_WORDS); ++wordIndex) {
        uint occupiedBits = entityOccupancyWords[wordIndex];
        while (occupiedBits != 0u) {
            uint bitIndex = uint(findLSB(occupiedBits));
            occupiedBits &= occupiedBits - 1u;
            uint cellIndex = wordIndex * OCCUPANCY_WORD_BITS + bitIndex;
            vec3 cellMinimum = entityGridOrigin.xyz +
                               ENTITY_CELL_SIZE * vec3(cellIndex & ENTITY_CELL_MASK,
                                                       (cellIndex >> ENTITY_ROW_SHIFT) & ENTITY_CELL_MASK,
                                                       cellIndex >> ENTITY_LAYER_SHIFT);
            vec3 cellMaximum = cellMinimum + ENTITY_CELL_SIZE;
            vec3 surfaceOffset = center - clamp(center, cellMinimum, cellMaximum);
            float surfaceDistance = length(surfaceOffset);
            float penetrationDepth = separationRadius - surfaceDistance;
            vec3 outwardNormal = vec3(0.0);
            if (surfaceDistance > 1e-6)
                outwardNormal = surfaceOffset / surfaceDistance;
            else {

                vec3 distanceToMinimum = center - cellMinimum, distanceToMaximum = cellMaximum - center;
                vec3 exitDistance = min(distanceToMinimum, distanceToMaximum);
                int exitAxis = exitDistance.x <= exitDistance.y && exitDistance.x <= exitDistance.z ? 0
                               : exitDistance.y <= exitDistance.z                                   ? 1
                                                                                                    : 2;
                outwardNormal[exitAxis] =
                    distanceToMinimum[exitAxis] <= distanceToMaximum[exitAxis] ? -1.0 : 1.0;
                penetrationDepth = separationRadius + exitDistance[exitAxis];
            }
            if (penetrationDepth > deepestContact.w)
                deepestContact = vec4(outwardNormal, penetrationDepth);
        }
    }
#endif
    return deepestContact;
}

#endif
