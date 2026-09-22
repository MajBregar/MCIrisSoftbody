#ifndef IRIS_SPHERE_LIB_CONFIG_SHADOW_TARGETS_GLSL
#define IRIS_SPHERE_LIB_CONFIG_SHADOW_TARGETS_GLSL 1

const int shadowMapResolution = 128;
#include "/lib/config/settings.glsl"

#if SIMULATION_DISTANCE <= 8
const float shadowDistance = 32.0;
#elif SIMULATION_DISTANCE <= 12
const float shadowDistance = 40.0;
#elif SIMULATION_DISTANCE <= 16
const float shadowDistance = 48.0;
#elif SIMULATION_DISTANCE <= 24
const float shadowDistance = 64.0;
#elif SIMULATION_DISTANCE <= 32
const float shadowDistance = 80.0;
#elif SIMULATION_DISTANCE <= 48
const float shadowDistance = 112.0;
#else
const float shadowDistance = 144.0;
#endif

#endif
