#version 440
// Samples the window snapshot and rounds its corners to match the real window.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bend;
    float slide;
    float targetX;
    float targetY;
    float itemW;
    float itemH;
    float iconW;
    float radius;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 size = vec2(itemW, itemH);
    vec2 q = abs(qt_TexCoord0 * size - 0.5 * size) - (0.5 * size - radius);
    float d = length(max(q, 0.0)) - radius;
    float mask = clamp(0.5 - d, 0.0, 1.0);
    fragColor = texture(source, qt_TexCoord0) * qt_Opacity * mask;
}
