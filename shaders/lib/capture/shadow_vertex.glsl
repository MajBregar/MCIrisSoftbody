#ifndef IRIS_SPHERE_LIB_CAPTURE_SHADOW_VERTEX_GLSL
#define IRIS_SPHERE_LIB_CAPTURE_SHADOW_VERTEX_GLSL 1
#include "/lib/config/constants.glsl"
#include "/lib/common/uniforms.glsl"

in vec2 mc_Entity;
out vec3 collisionPosition;
flat out int collisionFluid;
flat out int collisionBlockId;
flat out float collisionNormalY;

void main() {
    vec4 shadowView = gl_ModelViewMatrix * gl_Vertex;
    collisionPosition = (shadowModelViewInverse * shadowView).xyz;

    collisionBlockId = int(mc_Entity.x);

    collisionFluid = mc_Entity.y > 0.5 || mc_Entity.x == float(MATERIAL_WATER) || mc_Entity.x == float(MATERIAL_LAVA)
            ? (mc_Entity.x == float(MATERIAL_LAVA) ? MEDIUM_LAVA : MEDIUM_WATER)
            : MEDIUM_SOLID;

    collisionNormalY = (mat3(shadowModelViewInverse) * gl_NormalMatrix * gl_Normal).y;
    gl_Position = ftransform();
}

#endif
