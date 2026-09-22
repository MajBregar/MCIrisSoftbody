#ifndef IRIS_SPHERE_LIB_PASSES_UPDATE_MESH_GLSL
#define IRIS_SPHERE_LIB_PASSES_UPDATE_MESH_GLSL 1
#include "/lib/common/uniforms.glsl"
#include "/lib/data/buffers.glsl"

layout(local_size_x = CAPTURE_WORKGROUP_SIZE) in;
const ivec3 workGroups = ivec3(PARTICLE_GROUPS, 1, 1);

void main() {
    int particleIndex = int(gl_GlobalInvocationID.x);

    if (particleIndex >= VERTEX_COUNT)
        return;

    vec3 accumulatedNormal = vec3(0.0);
    for (int triangleIndex = 0; triangleIndex < TRIANGLE_COUNT; ++triangleIndex) {
        uvec3 triangleIndices = texelFetch(sphereIndices, ivec2(triangleIndex, 0), 0).xyz;

        if (any(equal(triangleIndices, uvec3(particleIndex)))) {
            vec3 triangleA = particlePositions[triangleIndices.x].xyz;
            vec3 triangleB = particlePositions[triangleIndices.y].xyz;
            vec3 triangleC = particlePositions[triangleIndices.z].xyz;
            accumulatedNormal += cross(triangleB - triangleA, triangleC - triangleA);
        }
    }

    particleNormals[particleIndex] = vec4(length(accumulatedNormal) > 1e-8 ? normalize(accumulatedNormal) : vec3(0.0, 1.0, 0.0), 0.0);

    if (particleIndex == 0) {
        vec3 minimumPosition = vec3(1e20);
        vec3 maximumPosition = vec3(-1e20);

        for (int otherParticleIndex = 0; otherParticleIndex < VERTEX_COUNT; ++otherParticleIndex) {
            minimumPosition = min(minimumPosition, particlePositions[otherParticleIndex].xyz);
            maximumPosition = max(maximumPosition, particlePositions[otherParticleIndex].xyz);
        }
        
        meshBoundsMin = vec4(minimumPosition - MESH_BOUNDS_PADDING, 0.0);
        meshBoundsMax = vec4(maximumPosition + MESH_BOUNDS_PADDING, 0.0);
    }
}

#endif
