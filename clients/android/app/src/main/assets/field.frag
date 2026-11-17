// The moire wallpaper's whole picture, back to front: ground, stars,
// bokeh, halftone dots, moire rings (the patterns fading out into the
// ground away from a drifting hub), foreground discs, then grain and
// dither over the finished pixel.
//
// Everything that moves is computed in Field.qml, in double precision,
// and arrives here as positions and phases; the shader holds no clock,
// so it never loses precision however long the session runs.
//
// Compiled into ../theme/contents/ui/field.frag.qsb by tools/shaders.sh.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;        // pixels
    // Positions and lengths below are in units of the shorter side, so
    // every aspect ratio, landscape or portrait, shows the same pattern
    // at the same apparent scale. The screen spans 0 to size / shorter.
    vec2 ringA;       // centres of the two ring families
    vec2 ringB;
    vec2 hub;         // where the pattern is strongest
    float reach;      // distance at which it has faded out entirely
    float period;     // ring spacing
    float moire;      // 0-1, how much of the rings to show
    float halftone;   // 0-1, how much of the dots to show
    float cell;       // halftone grid spacing
    float angle;      // halftone grid rotation, radians
    float wave;       // halftone wave phase, radians, kept in [0, 2pi)
    float bokeh;      // 0-1, how much of the bokeh to show
    float lights;     // how many bokeh discs, up to MAX_DISCS
    float flare;      // 0-1, how much of the large foreground discs to show
    float drift;      // bokeh phase, 0-1 over its whole cycle
    float stars;      // 0-1, how much of the starfield to show
    float twinkle;    // star phase, 0-1 over its whole cycle
    float glints;     // 0-1, how much light the glint catches
    float glintPhase; // 0-1 over one glint cycle; the sweep is its first 30%
    float breath;     // multiplies the patterns' strength, near 1
    float grain;      // 0-1, film grain
    float dither;     // 0-1, dither
    float seed;       // 0-1, changes each frame to move the grain

    vec4 base;        // the ground
    vec4 deep;        // the ground at the edges
    vec4 ink;         // the moire
    vec4 tone;        // the halftone
};

float fade(vec2 p)
{
    float t = clamp(1.0 - length(p - hub) / reach, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float rings(vec2 p, vec2 centre, float px)
{
    float r = length(p - centre);
    float d = abs(fract(r / period + 0.5) - 0.5) * period;
    float halfWidth = max(0.9 * px, period * 0.09);
    return clamp(1.0 - (d - halfWidth) / px, 0.0, 1.0);
}

// A repeatable pseudo-random number in [0, 1) per disc and purpose.
float hash(float n)
{
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// Per-pixel noise without sin() or integers: GLSL ES 100, one of the
// targets, has no unsigned integers, and sin() of a large pixel
// coordinate loses precision on some GPUs. (Dave Hoskins' hash12.)
float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Stars on a jittered grid, most faint and a few bright, each
// twinkling at a whole multiple of the twinkle phase so the wrap is
// seamless. A star sits well inside its cell, so only one cell needs
// checking per pixel. The brightest carry a soft halo.
float starLayer(vec2 p, float px, float spacing, float salt)
{
    vec2 id = floor(p / spacing) + salt;
    if (hash12(id) > 0.45)
        return 0.0;  // 45% of cells hold a star
    vec2 at = (floor(p / spacing) + 0.15 + 0.7 * vec2(hash12(id + 17.0), hash12(id + 31.0))) * spacing;
    float bright = hash12(id + 47.0);
    bright *= bright;
    float rate = 1.0 + floor(hash12(id + 59.0) * 4.0);
    float shimmer = 0.55 + 0.45 * sin(6.2831853 * (rate * twinkle + hash12(id + 71.0)));
    float r = px * (0.8 + 1.4 * bright);
    float d = length(p - at);
    float core = exp(-d * d / (r * r)) * (0.25 + 0.75 * bright);
    float halo = exp(-d / (7.0 * px)) * 0.18 * bright * bright * bright;
    return (core + halo) * shimmer;
}

// Two layers: the stars proper, and a denser scatter of fainter,
// smaller ones behind them that gives the field depth.
float starLight(vec2 p, float px)
{
    return starLayer(p, px, 0.035, 0.0) + 0.4 * starLayer(p, px, 0.016, 113.0);
}

// A band of light sweeping diagonally across the screen during the
// first 30% of each glint cycle. It lights only the rings and dots, as
// light catches fine grooves, and is zero between sweeps.
float glintBand(vec2 p, vec2 extent)
{
    if (glintPhase >= 0.3)
        return 0.0;
    float s = glintPhase / 0.3;
    vec2 dir = vec2(0.8, -0.6);
    float c0 = 0.0, c1 = extent.x * dir.x, c2 = extent.y * dir.y, c3 = c1 + c2;
    float lo = min(min(c0, c1), min(c2, c3));
    float hi = max(max(c0, c1), max(c2, c3));
    const float width = 0.08;
    float x = (dot(p, dir) - mix(lo - 3.0 * width, hi + 3.0 * width, s)) / width;
    return exp(-x * x) * sin(3.1415927 * s);
}

// Out-of-focus lights drifting upward. Each disc moves at a whole
// multiple of drift, so when drift wraps from 1 back to 0 every disc
// is exactly where it started; each fades in rising from the bottom
// and out before the top, so none ever appears or vanishes abruptly.
//
// Every disc has its own colour: somewhere from the primary to the
// accent, weighted towards the accent, and somewhere from muted to
// vivid. Returns the discs' blended colour and their combined coverage.
const int MAX_DISCS = 64;

vec4 bokehLight(vec2 p, vec2 extent, float px)
{
    // More discs means smaller ones, so a crowd stays a scatter of
    // lights rather than a haze.
    float scale = clamp(pow(14.0 / max(lights, 1.0), 0.3), 0.6, 1.2);

    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < MAX_DISCS; i++) {
        if (float(i) >= lights)
            break;
        float n = float(i);
        float climb = 1.0 + floor(hash(n + 1.0) * 3.0);       // 1-3 laps a cycle
        float sway = 1.0 + floor(hash(n + 2.0) * 2.0);
        float life = fract(hash(n + 3.0) + climb * drift);    // 0 at bottom, 1 at top
        vec2 c = vec2(hash(n + 4.0) * extent.x
                        + 0.04 * sin(6.2831853 * (sway * drift + hash(n + 5.0))),
                      extent.y + 0.15 - (extent.y + 0.3) * life);
        float radius = (0.035 + 0.075 * hash(n + 6.0)) * scale;
        float d = length(p - c);
        float disc = clamp((radius - d) / (2.5 * px) + 0.5, 0.0, 1.0);
        // A lens renders a defocused point with a slightly brighter rim.
        float rim = smoothstep(radius * 0.7, radius, d) * disc;
        float shape = disc * 0.65 + rim * 0.35;
        float strength = shape * sin(3.1415927 * life) * (0.45 + 0.55 * hash(n + 7.0));

        vec3 colour = mix(tone.rgb, ink.rgb, sqrt(hash(n + 8.0)));
        float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
        colour = clamp(mix(vec3(grey), colour, 0.3 + 0.9 * hash(n + 9.0)), 0.0, 1.0);

        sum += colour * strength;
        total += strength;
    }
    return vec4(total > 0.0 ? sum / total : vec3(0.0), min(total, 1.0));
}

// A few large, very defocused discs in front of everything, like a
// light passing close to the lens. Each is visible for about a third
// of its cycle, fading in and out as it slides across, and absent the
// rest of the time, so they come by every so often rather than always.
// As with the bokeh, whole-number laps keep the drift wrap seamless.
const int FLARES = 3;

vec4 foregroundLight(vec2 p, vec2 extent)
{
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < FLARES; i++) {
        float n = float(i) + 40.0;
        float laps = 1.0 + floor(hash(n) * 2.0);             // 1-2 visits a cycle
        float life = fract(hash(n + 1.0) + laps * drift);
        float window = life / 0.35;                          // visible for the first 35%
        if (window >= 1.0)
            continue;
        float envelope = sin(3.1415927 * window);
        envelope *= envelope;                                // ease in and out
        float fromRight = step(0.5, hash(n + 2.0));
        float x = mix(-0.2, extent.x + 0.2, hash(n + 3.0))
                + mix(0.35, -0.35, fromRight) * window;
        vec2 c = vec2(x, mix(0.15, 0.85, hash(n + 4.0)) * extent.y - 0.12 * window);
        float radius = 0.22 + 0.2 * hash(n + 5.0);
        float d = length(p - c);
        // Far out of focus: a wide soft edge and only a hint of a rim.
        float disc = 1.0 - smoothstep(radius * 0.72, radius, d);
        float rim = smoothstep(radius * 0.6, radius * 0.88, d) * disc;
        float strength = (disc * 0.8 + rim * 0.2) * envelope;

        sum += mix(tone.rgb, ink.rgb, 0.6 + 0.4 * hash(n + 6.0)) * strength;
        total += strength;
    }
    return vec4(total > 0.0 ? sum / total : vec3(0.0), min(total, 1.0));
}

void main()
{
    float px = 1.0 / min(size.x, size.y);
    vec2 extent = size * px;
    vec2 p = qt_TexCoord0 * extent;
    vec2 centre = 0.5 * extent;

    // Ground: base, darkening towards deep at the corners.
    float v = smoothstep(0.35, 1.25, length(p - centre));
    vec3 colour = mix(base.rgb, deep.rgb, v);

    if (stars > 0.0)
        colour = mix(colour, ink.rgb, starLight(p, px) * 0.85 * stars);

    float glint = glints > 0.0 ? glintBand(p, extent) * glints : 0.0;

    if (bokeh > 0.0) {
        vec4 light = bokehLight(p, extent, px);
        colour = mix(colour, light.rgb, light.a * 0.3 * bokeh);
    }

    // Halftone: dots on a rotated grid, each sized by the fade and a
    // travelling wave sampled at its cell's centre, so a dot is round
    // and uniform rather than cut by the field. Area, not radius, is
    // proportional to the field, as in print.
    if (halftone > 0.0) {
        mat2 rot = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));
        vec2 q = rot * p;
        vec2 index = floor(q / cell);
        vec2 local = (q / cell - index - 0.5) * cell;
        vec2 cellCentre = transpose(rot) * ((index + 0.5) * cell);
        float field = fade(cellCentre)
                    * (0.55 + 0.45 * sin(dot(cellCentre, vec2(0.8, 0.6)) * 9.0 - wave));
        float radius = 0.5 * cell * sqrt(field);
        float dotCover = clamp((radius - length(local)) / px + 0.5, 0.0, 1.0);
        colour = mix(colour, tone.rgb, dotCover * halftone * breath * 0.55);
        colour = mix(colour, ink.rgb, dotCover * halftone * glint * 0.5);
    }

    // Moire: two ring families slightly apart. Where their rings
    // interleave the light doubles up, where they coincide it thins
    // out, and that beat is the moire.
    if (moire > 0.0) {
        float a = rings(p, ringA, px);
        float b = rings(p, ringB, px);
        float light = 1.0 - (1.0 - 0.85 * a) * (1.0 - 0.85 * b);
        float f = fade(p);
        colour = mix(colour, ink.rgb, light * 0.6 * f * moire * breath);
        // The glint reaches a little past the fade, catching rings the
        // eye had lost.
        colour = mix(colour, mix(ink.rgb, vec3(1.0), 0.3), light * glint * moire * (0.4 + 0.6 * f) * 0.55);
    }

    // In front of everything, so drawn last.
    if (flare > 0.0) {
        vec4 light = foregroundLight(p, extent);
        colour = mix(colour, light.rgb, light.a * 0.11 * flare);
    }

    vec2 pixel = qt_TexCoord0 * size;
    if (grain > 0.0)
        colour += (hash12(pixel + seed * 1000.0) - 0.5) * 0.06 * grain;
    // Triangular noise of about one 8-bit step: invisible as noise, but
    // it breaks the slow gradients' banding into something smooth.
    if (dither > 0.0)
        colour += (hash12(pixel + 0.5) + hash12(pixel + 91.3) - 1.0) / 255.0 * dither;

    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
