#ifndef IRIS_SPHERE_LIB_RENDER_FULLSCREEN_VERTEX_GLSL
#define IRIS_SPHERE_LIB_RENDER_FULLSCREEN_VERTEX_GLSL 1

out vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
