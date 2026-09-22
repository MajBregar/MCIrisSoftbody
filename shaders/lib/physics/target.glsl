#ifndef IRIS_SPHERE_LIB_PHYSICS_TARGET_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_TARGET_GLSL 1

#include "/lib/config/constants.glsl"
#include "/lib/common/uniforms.glsl"
vec3 targetCenter() {
    vec3 targetPositionPlayerSpace = vec3(SPHERE_X, SPHERE_Y, SPHERE_Z);
#if SPHERE_SPACE == 1
    targetPositionPlayerSpace = (gbufferModelViewInverse * vec4(targetPositionPlayerSpace, 1.0)).xyz;
#endif
    return targetPositionPlayerSpace;
}

vec3 targetPosition(int particleIndex) {
    vec3 targetPositionPlayerSpace = vec3(SPHERE_X, SPHERE_Y, SPHERE_Z) +
                                     SPHERE_RADIUS * texelFetch(sphereRest, ivec2(particleIndex, 0), 0).xyz;
#if SPHERE_SPACE == 1
    targetPositionPlayerSpace = (gbufferModelViewInverse * vec4(targetPositionPlayerSpace, 1.0)).xyz;
#endif
    return targetPositionPlayerSpace;
}

bool needsReset(int particleIndex) {
    return particlePositions[particleIndex].w < 0.0 ||
           length(previousCameraPosition - cameraPosition) > TELEPORT_RESET_DISTANCE;
}

vec3 initialVelocity() {
#if BALL_MODE == 1
    vec3 launchVelocity = vec3(0.0, 0.0, -FREE_LAUNCH_SPEED);
#if SPHERE_SPACE == 1
    launchVelocity = mat3(gbufferModelViewInverse) * launchVelocity;
#endif
    return launchVelocity;
#else
    return vec3(0.0);
#endif
}

#endif
