// Prism: one glowing beam comes in from a set angle and hits a slowly
// turning shape (a circle or a regular polygon), which throws out a
// fan of smaller rays. The rays turn around the shape, each wanders a
// little on its own, and each has its own width, every one slowly
// swelling and thinning at a different rate.
//
// Written in the same Qt header style as field.frag, so Shader.kt's
// (and the site's) `toGles` reads it as is. As there, everything that
// moves is computed in double precision on the CPU (Field.qml,
// Motion.kt) and arrives here as wrapped phases: the shader holds no
// clock.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;        // pixels
    // Positions and lengths in units of the shorter side, as in field.frag.
    vec2 centre;      // the shape's centre
    float radius;     // the shape's circumradius
    float sides;      // 0 for a circle, else 3 to 8
    float spin;       // the shape's rotation, radians, kept in [0, 2pi)
    float beamAngle;  // the way the beam travels, radians, 0 = rightward
    float rays;       // how many rays come out, up to MAX_RAYS
    float rayTurn;    // the rays' shared rotation, radians, in [0, 2pi)
    float cycle;      // 0-1; each ray's wander and width change by whole laps of it
    float breath;     // multiplies the light, near 1
    float grain;      // 0-1, film grain
    float dither;     // 0-1, dither
    float seed;       // 0-1, changes each frame to move the grain

    vec4 base;        // the ground
    vec4 deep;        // the ground at the edges
    vec4 ink;         // the beam, the shape's edge
    vec4 tone;        // the rays lean towards this
};

const float TAU = 6.2831853;
const int MAX_RAYS = 24;

float hash(float n)
{
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Signed distance to the shape, centred at the origin: negative inside.
float shapeDistance(vec2 q)
{
    if (sides < 2.5)
        return length(q) - radius;
    float sector = TAU / sides;
    float a = atan(q.y, q.x);
    float apothem = radius * cos(0.5 * sector);
    return cos(floor(0.5 + a / sector) * sector - a) * length(q) - apothem;
}

// A ray leaving the centre along `dir`: a bright core `width` wide and a
// softer halo, both widening a little and fading as it goes.
float ray(vec2 q, vec2 dir, float width, float reach)
{
    float along = dot(q, dir);
    if (along <= 0.0)
        return 0.0;
    float across = abs(q.x * dir.y - q.y * dir.x);
    float w = width * (1.0 + 0.6 * along);
    float core = exp(-(across * across) / (w * w));
    float halo = exp(-across / (4.0 * w)) * 0.2;
    return (core + halo) * exp(-along / reach);
}

void main()
{
    float px = 1.0 / min(size.x, size.y);
    vec2 extent = size * px;
    vec2 p = qt_TexCoord0 * extent;
    vec2 q = p - centre;

    float v = smoothstep(0.35, 1.25, length(p - 0.5 * extent));
    vec3 colour = mix(base.rgb, deep.rgb, v);

    // The shape, turned.
    mat2 rot = mat2(cos(spin), -sin(spin), sin(spin), cos(spin));
    float d = shapeDistance(rot * q);
    float outside = smoothstep(-px, px, d);

    vec3 light = vec3(0.0);

    // The beam, from off screen up to the shape. Its far end is the
    // centre, under the shape's fill.
    vec2 dirIn = vec2(cos(beamAngle), sin(beamAngle));
    {
        float along = dot(q, dirIn);
        float across = abs(q.x * dirIn.y - q.y * dirIn.x);
        float w = radius * 0.11;
        float core = exp(-(across * across) / (w * w));
        float hot = exp(-(across * across) / (0.12 * w * w));
        float halo = exp(-across / (3.0 * w)) * 0.35;
        float beam = along < 0.0 ? 1.0 : exp(-along * along / (radius * radius * 0.05));
        light += (mix(ink.rgb, vec3(1.0), 0.35) * (core + halo) + vec3(0.6) * hot) * beam;
    }

    // The rays: spread around the shape, turning together, each with its
    // own wander and width. Whole laps of `cycle` keep its wrap seamless,
    // and different lap counts keep every ray's width changing at its own
    // rate.
    for (int i = 0; i < MAX_RAYS; i++) {
        if (float(i) >= rays)
            break;
        float n = float(i) * 7.31 + 1.7;
        float wander = 0.35 * (hash(n) - 0.5) + 0.06 * sin(TAU * ((1.0 + mod(float(i), 3.0)) * cycle + hash(n + 1.0)));
        float a = TAU * (float(i) + wander) / rays + rayTurn;
        vec2 dir = vec2(cos(a), sin(a));
        float swell = 0.5 + 0.5 * sin(TAU * (float(i + 2) * cycle + hash(n + 2.0)));
        float width = radius * (0.012 + 0.05 * hash(n + 3.0)) * (0.35 + 0.9 * swell);
        float reach = 0.5 + 0.9 * hash(n + 4.0);
        float strength = 0.55 + 0.45 * hash(n + 5.0);
        vec3 tint = mix(ink.rgb, tone.rgb, 0.3 + 0.7 * hash(n + 6.0));
        light += mix(tint, vec3(1.0), 0.15) * ray(q, dir, width, reach) * strength;
    }

    light *= breath;
    // Soft-clip, so where light piles up it whitens rather than clipping.
    colour += (vec3(1.0) - exp(-light * 1.1)) * outside;

    // The shape: dark glass with a glowing edge, brightest where the beam
    // strikes, and a glow just outside.
    vec2 normal = q / max(length(q), 1e-4);
    float lit = 0.35 + 0.65 * max(0.0, -dot(normal, dirIn));
    vec3 glass = mix(mix(deep.rgb, ink.rgb, 0.1), ink.rgb, 0.25 * smoothstep(-radius, 0.0, d) * lit);
    colour = mix(glass, colour, outside);
    float edge = exp(-abs(d) / (2.5 * px + radius * 0.012));
    float glow = exp(-max(d, 0.0) / (radius * 0.18)) * 0.25 * outside;
    colour += mix(ink.rgb, vec3(1.0), 0.3) * (edge * 0.8 + glow) * lit * breath;

    vec2 pixel = qt_TexCoord0 * size;
    if (grain > 0.0)
        colour += (hash12(pixel + seed * 1000.0) - 0.5) * 0.06 * grain;
    if (dither > 0.0)
        colour += (hash12(pixel + 0.5) + hash12(pixel + 91.3) - 1.0) / 255.0 * dither;

    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
