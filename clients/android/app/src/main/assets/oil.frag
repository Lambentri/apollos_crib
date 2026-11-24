// Oil on glass: slicks of thin film on dark glass, banded light and dark
// as an oil film's interference is, in one colour, swirling slowly. The swirl is
// domain-warped noise sampled at two points in its drift, crossfaded so
// each is invisible as it jumps back: the shader holds no clock, only a
// wrapped phase, as field.frag.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;        // pixels
    float oilCycle;   // 0-1 over one drift
    float coverage;   // 0-1, how much of the glass the slicks cover
    float breath;     // multiplies the film's strength, near 1
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

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p)
{
    float sum = 0.0;
    float amp = 0.5;
    mat2 turn = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        sum += amp * noise(p);
        p = turn * p * 2.02 + 17.1;
        amp *= 0.5;
    }
    return sum;
}

// The film's thickness, and how much film there is, at time t.
vec2 film(vec2 p, float t)
{
    vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, -t) + 1.3));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + 0.5 * t), fbm(p + 3.0 * q + vec2(8.3, 2.8) - 0.5 * t));
    float thick = fbm(p + 2.5 * r);
    float lo = mix(0.78, 0.3, coverage);
    float slick = smoothstep(lo, lo + 0.14, fbm(p * 0.6 + 1.5 * q - 0.3 * t + 40.0));
    return vec2(thick, slick);
}

void main()
{
    float px = 1.0 / min(size.x, size.y);
    vec2 extent = size * px;
    vec2 p = qt_TexCoord0 * extent;

    float v = smoothstep(0.35, 1.25, length(p - 0.5 * extent));
    vec3 colour = mix(base.rgb, deep.rgb, v);

    // Two samples half a drift apart, each weighted to nothing as it wraps.
    float a = oilCycle;
    float b = fract(oilCycle + 0.5);
    float w = abs(2.0 * a - 1.0);
    vec2 s1 = film(p * 2.2, a * 6.0);
    vec2 s2 = film(p * 2.2 + 31.7, b * 6.0);
    vec2 f = mix(s1, s2, w);

    // Interference bands, monochrome: the film goes light and dark as it
    // thickens, in the theme's ink.
    float th = f.x * 3.2;
    float band = 0.5 + 0.5 * cos(TAU * th);
    vec3 tint = mix(mix(deep.rgb, ink.rgb, 0.35), ink.rgb, band);
    // Thin film at the slick's edge is brightest; its thick heart darker.
    float edge = f.y * (1.0 - f.y) * 4.0;
    float strength = f.y * (0.28 + 0.4 * edge) * breath;
    colour = mix(colour, tint, strength);
    colour = mix(colour, deep.rgb, f.y * smoothstep(0.62, 0.8, f.x) * 0.35);

    // The glass: a faint sheen in a long diagonal.
    float sheen = exp(-pow(dot(p - 0.5 * extent, vec2(0.6, 0.8)) / 0.35, 2.0));
    colour += vec3(0.04) * sheen;

    vec2 pixel = qt_TexCoord0 * size;
    if (grain > 0.0)
        colour += (hash12(pixel + seed * 1000.0) - 0.5) * 0.06 * grain;
    if (dither > 0.0)
        colour += (hash12(pixel + 0.5) + hash12(pixel + 91.3) - 1.0) / 255.0 * dither;

    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
