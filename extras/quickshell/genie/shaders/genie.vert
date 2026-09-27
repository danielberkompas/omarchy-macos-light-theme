#version 440
// Genie warp: the window's lower edge is pulled into the dock icon, bending the
// window into a funnel, then the whole window slides down the funnel into it.
// Coordinates are in item-local pixels; the item covers the window's rect.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bend;     // 0..1: bottom edge stretches down and pinches into the icon
    float slide;    // 0..1: window flows down the funnel into the icon
    float targetX;  // icon centre, item-local
    float targetY;  // icon centre, item-local (below the window)
    float itemW;
    float itemH;
    float iconW;    // width of the funnel's neck
    float radius;   // window corner radius (fragment shader)
};

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    vec4 pos = qt_Vertex;

    float v = qt_Vertex.y / itemH;                       // 0 at top, 1 at bottom
    float stretched = qt_Vertex.y + v * (targetY - itemH) * bend;
    pos.y = mix(stretched, targetY, slide);

    float t = clamp(pos.y / targetY, 0.0, 1.0);
    t = t * t * (3.0 - 2.0 * t);                         // smooth funnel profile
    float neckX = targetX + (qt_Vertex.x / itemW - 0.5) * iconW;
    pos.x = mix(qt_Vertex.x, neckX, t * bend);

    gl_Position = qt_Matrix * pos;
}
