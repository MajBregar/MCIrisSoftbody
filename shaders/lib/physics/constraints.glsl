#ifndef IRIS_SPHERE_LIB_PHYSICS_CONSTRAINTS_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_CONSTRAINTS_GLSL 1

// Disjoint edge colors avoid concurrent writes; volume reductions synchronize all lanes.
void solveTetherConstraint(int particleIndex, bool activeParticle, vec4 particleTotals, vec3 bodyCenter,
                           vec3 tetherTarget) {
#if GRAB_ENABLED == 1 && BALL_MODE == 0
    float tetherCompliance = GRAB_COMPLIANCE / (PHYSICS_TIMESTEP * PHYSICS_TIMESTEP);
    vec3 tetherMultiplierDelta = (-(bodyCenter - tetherTarget) - tetherCompliance * tetherMultiplier) /
                                 (particleTotals.w / float(VERTEX_COUNT * VERTEX_COUNT) + tetherCompliance);

    barrier();
    if (particleIndex == 0)
        tetherMultiplier += tetherMultiplierDelta;
    if (activeParticle)
        predictedParticles[particleIndex].xyz +=
            predictedParticles[particleIndex].w * tetherMultiplierDelta / float(VERTEX_COUNT);
    barrier();
#endif
}

void solveDistanceConstraints(int particleIndex) {

    for (int colorGroup = 0; colorGroup < EDGE_COLOR_COUNT; ++colorGroup) {
        for (int edgeIndex = edgeColorOffsets[colorGroup] + particleIndex;
             edgeIndex < edgeColorOffsets[colorGroup + 1]; edgeIndex += SOLVER_WORKGROUP_SIZE) {
            vec4 edgeData = texelFetch(sphereEdges, ivec2(edgeIndex, 0), 0);
            int vertexA = int(edgeData.x), vertexB = int(edgeData.y);
            vec3 delta = predictedParticles[vertexA].xyz - predictedParticles[vertexB].xyz;
            float edgeLength = length(delta);
            float distanceCompliance = DISTANCE_COMPLIANCE / (PHYSICS_TIMESTEP * PHYSICS_TIMESTEP);
            float constraintDenominator =
                predictedParticles[vertexA].w + predictedParticles[vertexB].w + distanceCompliance;
            if (edgeLength > 1e-8 && constraintDenominator > 1e-12) {
                float distanceMultiplierDelta = (-(edgeLength - edgeData.z * SPHERE_RADIUS) -
                                                 distanceCompliance * distanceMultipliers[edgeIndex]) /
                                                constraintDenominator;
                distanceMultipliers[edgeIndex] += distanceMultiplierDelta;
                vec3 correction = (distanceMultiplierDelta / edgeLength) * delta;
                predictedParticles[vertexA].xyz += predictedParticles[vertexA].w * correction;
                predictedParticles[vertexB].xyz -= predictedParticles[vertexB].w * correction;
            }
        }
        barrier();
    }
}

void solveVolumeConstraint(int particleIndex, bool activeParticle, vec3 bodyCenter) {

    vec3 volumeGradient = vec3(0.0);
    if (activeParticle) {
        for (int adjacencyIndex = 0; adjacencyIndex < textureSize(sphereAdjacency, 0).x; ++adjacencyIndex) {
            uint encodedTriangle = texelFetch(sphereAdjacency, ivec2(adjacencyIndex, particleIndex), 0).x;
            if (encodedTriangle == 0u)
                continue;
            uvec3 triangleIndices = texelFetch(sphereIndices, ivec2(int(encodedTriangle - 1u), 0), 0).xyz;
            vec3 vertexA = predictedParticles[triangleIndices.x].xyz - bodyCenter;
            vec3 vertexB = predictedParticles[triangleIndices.y].xyz - bodyCenter;
            vec3 vertexC = predictedParticles[triangleIndices.z].xyz - bodyCenter;
            volumeGradient += (triangleIndices.x == uint(particleIndex)   ? cross(vertexB, vertexC)
                               : triangleIndices.y == uint(particleIndex) ? cross(vertexC, vertexA)
                                                                          : cross(vertexA, vertexB)) /
                              6.0;
        }
    }
    float partialVolume = 0.0;
    for (int triangleIndex = particleIndex; triangleIndex < TRIANGLE_COUNT;
         triangleIndex += SOLVER_WORKGROUP_SIZE) {
        uvec3 triangleIndices = texelFetch(sphereIndices, ivec2(triangleIndex, 0), 0).xyz;
        vec3 vertexA = predictedParticles[triangleIndices.x].xyz - bodyCenter;
        vec3 vertexB = predictedParticles[triangleIndices.y].xyz - bodyCenter;
        vec3 vertexC = predictedParticles[triangleIndices.z].xyz - bodyCenter;
        partialVolume += dot(vertexA, cross(vertexB, vertexC)) / 6.0;
    }
    vec4 volumeTotals = sumWorkgroup(
        vec4(partialVolume,
             activeParticle ? predictedParticles[particleIndex].w * dot(volumeGradient, volumeGradient) : 0.0,
             0.0, 0.0));
    float volumeCompliance = VOLUME_COMPLIANCE / (PHYSICS_TIMESTEP * PHYSICS_TIMESTEP);
    float volumeDenominator = volumeTotals.y + volumeCompliance;
    float volumeMultiplierDelta =
        volumeDenominator > 1e-12
            ? (-(volumeTotals.x - REST_VOLUME * SPHERE_RADIUS * SPHERE_RADIUS * SPHERE_RADIUS) -
               volumeCompliance * volumeMultiplier) /
                  volumeDenominator
            : 0.0;
    barrier();
    if (particleIndex == 0)
        volumeMultiplier += volumeMultiplierDelta;
    if (activeParticle)
        predictedParticles[particleIndex].xyz +=
            predictedParticles[particleIndex].w * volumeGradient * volumeMultiplierDelta;
}

#endif
