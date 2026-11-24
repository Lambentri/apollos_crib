// Bubbles: soap bubbles drifting and bouncing (moved on the CPU, in
// balls.js, Balls.kt and the site's shader_balls.js).
// Each is nearly clear, its film banded light and dark in one colour and
// swirling, brighter towards the rim, with a window's highlight.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;        // pixels
    // ball0-ball47: x, y, radius (shorter side units), film phase 0-1
    vec4 ball0;
    vec4 ball1;
    vec4 ball2;
    vec4 ball3;
    vec4 ball4;
    vec4 ball5;
    vec4 ball6;
    vec4 ball7;
    vec4 ball8;
    vec4 ball9;
    vec4 ball10;
    vec4 ball11;
    vec4 ball12;
    vec4 ball13;
    vec4 ball14;
    vec4 ball15;
    vec4 ball16;
    vec4 ball17;
    vec4 ball18;
    vec4 ball19;
    vec4 ball20;
    vec4 ball21;
    vec4 ball22;
    vec4 ball23;
    vec4 ball24;
    vec4 ball25;
    vec4 ball26;
    vec4 ball27;
    vec4 ball28;
    vec4 ball29;
    vec4 ball30;
    vec4 ball31;
    vec4 ball32;
    vec4 ball33;
    vec4 ball34;
    vec4 ball35;
    vec4 ball36;
    vec4 ball37;
    vec4 ball38;
    vec4 ball39;
    vec4 ball40;
    vec4 ball41;
    vec4 ball42;
    vec4 ball43;
    vec4 ball44;
    vec4 ball45;
    vec4 ball46;
    vec4 ball47;
    float count;      // how many of balls are in use
    float breath;     // multiplies the light, near 1
    float grain;      // 0-1, film grain
    float dither;     // 0-1, dither
    float seed;       // 0-1, changes each frame to move the grain

    vec4 base;        // the ground
    vec4 deep;        // the ground at the edges
    vec4 ink;
    vec4 tone;
};

const float TAU = 6.2831853;

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main()
{
    float px = 1.0 / min(size.x, size.y);
    vec2 extent = size * px;
    vec2 p = qt_TexCoord0 * extent;

    // The discs, gathered into an array the loop can index. They arrive
    // as separate uniforms because Qt's ShaderEffect has no array
    // properties: x, y, radius (shorter side units), and a fourth value.
    vec4 balls[48] = vec4[48](
        ball0, ball1, ball2, ball3, ball4, ball5, ball6, ball7,
        ball8, ball9, ball10, ball11, ball12, ball13, ball14, ball15,
        ball16, ball17, ball18, ball19, ball20, ball21, ball22, ball23,
        ball24, ball25, ball26, ball27, ball28, ball29, ball30, ball31,
        ball32, ball33, ball34, ball35, ball36, ball37, ball38, ball39,
        ball40, ball41, ball42, ball43, ball44, ball45, ball46, ball47);

    float v = smoothstep(0.35, 1.25, length(p - 0.5 * extent));
    vec3 colour = mix(base.rgb, deep.rgb, v);

    vec3 light = vec3(0.0);
    for (int i = 0; i < 48; i++) {
        if (float(i) >= count)
            break;
        vec4 b = balls[i];
        vec2 q = (p - b.xy) / b.z;
        float d = length(q);
        if (d > 1.2)
            continue;
        float inside = clamp((1.0 - d) * b.z / px + 0.5, 0.0, 1.0);

        // The film: thickness varying down the bubble (it drains) and
        // swirling around it.
        float ang = atan(q.y, q.x);
        float th = b.w + 0.45 * q.y + 0.15 * d * sin(2.0 * ang + TAU * b.w) + 0.3 * d * d;
        vec3 iris = ink.rgb * (0.55 + 0.45 * cos(TAU * 1.6 * th));
        float fresnel = d * d * d * d;
        light += iris * (0.05 + 0.5 * fresnel) * inside;

        // A thin bright rim, and a little glow outside it.
        float rim = exp(-abs(d - 1.0) * b.z / (1.2 * px + 0.0025));
        light += mix(iris, vec3(1.0), 0.4) * rim * 0.35;

        // A window's highlight up and to the left, a fainter one opposite.
        vec2 h = q - vec2(-0.38, -0.42);
        float hl = exp(-dot(h, h) / 0.018);
        vec2 h2 = q - vec2(0.42, 0.45);
        float hl2 = exp(-dot(h2, h2) / 0.01);
        light += vec3(1.0) * (0.55 * hl + 0.18 * hl2) * inside;
    }
    colour += (vec3(1.0) - exp(-light)) * breath;

    vec2 pixel = qt_TexCoord0 * size;
    if (grain > 0.0)
        colour += (hash12(pixel + seed * 1000.0) - 0.5) * 0.06 * grain;
    if (dither > 0.0)
        colour += (hash12(pixel + 0.5) + hash12(pixel + 91.3) - 1.0) / 255.0 * dither;

    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
