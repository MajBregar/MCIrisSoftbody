#ifndef IRIS_SPHERE_LIB_COMMON_MATH_GLSL
#define IRIS_SPHERE_LIB_COMMON_MATH_GLSL 1

vec3 limitVectorLength(vec3 value, float maximum) {
    return value * min(1.0, maximum / max(length(value), 1e-12));
}

#endif
