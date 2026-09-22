#ifndef IRIS_SPHERE_LIB_RENDER_MATERIAL_VERTEX_GLSL
#define IRIS_SPHERE_LIB_RENDER_MATERIAL_VERTEX_GLSL 1

out vec2 texcoord;
out vec2 lmcoord;
out vec4 vertexColor;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
}

#endif
