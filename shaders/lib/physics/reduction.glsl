#ifndef IRIS_SPHERE_LIB_PHYSICS_REDUCTION_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_REDUCTION_GLSL 1

// Every lane must call this reduction in the same order, including inactive particles.
vec4 sumWorkgroup(vec4 value) {
    uint laneIndex = gl_LocalInvocationID.x;
    reductionScratch[laneIndex] = value;
    barrier();
    for (uint stride = uint(SOLVER_WORKGROUP_SIZE / 2); stride > 0u; stride >>= 1u) {
        if (laneIndex < stride)
            reductionScratch[laneIndex] += reductionScratch[laneIndex + stride];
        barrier();
    }
    vec4 result = reductionScratch[0];
    barrier();
    return result;
}

#endif
