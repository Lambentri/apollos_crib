package io.neiam.apolloscrib.ui.theme

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color as AndroidColor
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin

// Ported from dms/android — which took it from cbz-numerics-android — so the
// same OKLCh palettes carry across the network's apps. "Her" and "After Dark"
// are the same two the Scribus public routes render under in apollos-crib;
// keeping the names aligned means a phone and a panel showing the same vision
// look like the same thing.

private fun oklchToColor(l: Float, c: Float, hDeg: Float, alpha: Float = 1f): Color {
    val hRad = Math.toRadians(hDeg.toDouble()).toFloat()
    val a = c * cos(hRad)
    val b = c * sin(hRad)
    val lCbrt = l + 0.3963377774f * a + 0.2158037573f * b
    val mCbrt = l - 0.1055613458f * a - 0.0638541728f * b
    val sCbrt = l - 0.0894841775f * a - 1.2914855480f * b
    val lL = lCbrt * lCbrt * lCbrt
    val mL = mCbrt * mCbrt * mCbrt
    val sL = sCbrt * sCbrt * sCbrt
    val rL = +4.0767416621f * lL - 3.3077115913f * mL + 0.2309699292f * sL
    val gL = -1.2684380046f * lL + 2.6097574011f * mL - 0.3413193965f * sL
    val bL = -0.0041960863f * lL - 0.7034186147f * mL + 1.7076147010f * sL
    fun gamma(x: Float): Int {
        val v = x.coerceIn(0f, 1f)
        val s = if (v <= 0.0031308f) 12.92f * v else 1.055f * v.pow(1f / 2.4f) - 0.055f
        return (s * 255f + 0.5f).toInt().coerceIn(0, 255)
    }
    val argb = AndroidColor.argb(
        (alpha * 255f + 0.5f).toInt().coerceIn(0, 255),
        gamma(rL), gamma(gL), gamma(bL),
    )
    return Color(argb)
}

data class AppTheme(
    val name: String,
    val key: String,
    val bg: Color,
    val cardBg: Color,
    val content: Color,
    val primary: Color,
    val dim: Color,
    val accent: Color,
    val liveGreen: Color,
    val isLight: Boolean = false,
) {
    fun toColorScheme() = if (isLight) {
        lightColorScheme(
            primary = primary, onPrimary = content,
            primaryContainer = cardBg, onPrimaryContainer = content,
            secondary = accent, onSecondary = bg,
            background = bg, onBackground = content,
            surface = bg, onSurface = content,
            surfaceVariant = cardBg, onSurfaceVariant = dim,
            // Material3 Card / dropdown / dialog default to one of the
            // `surfaceContainer*` tones for their container colour. Without
            // overrides we'd inherit Material's neutral greys; pin them to
            // the theme's `cardBg` so cards actually look themed.
            surfaceContainerLowest = cardBg,
            surfaceContainerLow    = cardBg,
            surfaceContainer       = cardBg,
            surfaceContainerHigh   = cardBg,
            surfaceContainerHighest = cardBg,
            // surfaceTint is mixed in based on elevation — left at Material's
            // default it bleeds primary into every elevated surface. Match
            // it to `primary` so the theme's accent shows up at higher
            // elevations rather than a generic purple.
            surfaceTint = primary,
            outline = dim, outlineVariant = dim.copy(alpha = 0.35f),
        )
    } else {
        darkColorScheme(
            primary = primary, onPrimary = content,
            primaryContainer = cardBg, onPrimaryContainer = content,
            secondary = accent, onSecondary = bg,
            background = bg, onBackground = content,
            surface = bg, onSurface = content,
            surfaceVariant = cardBg, onSurfaceVariant = dim,
            surfaceContainerLowest = cardBg,
            surfaceContainerLow    = cardBg,
            surfaceContainer       = cardBg,
            surfaceContainerHigh   = cardBg,
            surfaceContainerHighest = cardBg,
            surfaceTint = primary,
            outline = dim, outlineVariant = dim.copy(alpha = 0.35f),
        )
    }
}

private fun oklchTheme(
    name: String, key: String,
    bgL: Float, bgC: Float, bgH: Float,
    cardL: Float, cardC: Float, cardH: Float,
    contentL: Float, contentC: Float, contentH: Float,
    primaryL: Float, primaryC: Float, primaryH: Float,
    dimL: Float, dimC: Float, dimH: Float,
    // The six neiam themes all share daisyUI's yellow accent, so it
    // defaults to that; light and dark pass their own explicitly.
    accentL: Float = 0.96f, accentC: Float = 0.058f, accentH: Float = 96f,
    isLight: Boolean = false,
) = AppTheme(
    name = name, key = key,
    bg        = oklchToColor(bgL, bgC, bgH),
    cardBg    = oklchToColor(cardL, cardC, cardH),
    content   = oklchToColor(contentL, contentC, contentH),
    primary   = oklchToColor(primaryL, primaryC, primaryH),
    dim       = oklchToColor(dimL, dimC, dimH),
    accent    = oklchToColor(accentL, accentC, accentH),
    liveGreen = oklchToColor(0.75f, 0.15f, 145f),
    isLight   = isLight,
)

val ALL_THEMES: List<AppTheme> = listOf(
    // light and dark are the pair the sibling apps' web frontends declare in
    // daisyUI (bigtrippr, waxx, feedpug, gitgud): bg is --color-base-100,
    // cardBg is --color-base-200, content is --color-base-content, and
    // primary/accent are theirs. apollos-crib's own Scribus routes have no
    // light/dark of their own, so these come from that shared set. `dim` has
    // no web token -- it paints Material's outline and onSurfaceVariant -- so
    // it is the 60% blend of content over bg, which is what the web writes as
    // text-base-content/60.
    oklchTheme(
        "Light", "light",
        0.98f, 0.008f, 24f,         // base-100
        0.96f, 0.014f, 24f,         // base-200
        0.25f, 0.050f, 24f,         // base-content
        0.64f, 0.076f, 19f,         // primary
        0.54f, 0.033f, 24f,         // dim
        0.0f, 0.0f, 0f,             // accent: light's is pure black
        isLight = true,
    ),
    oklchTheme("Her",        "her",        0.18f, 0.095f, 24f,  0.22f, 0.070f, 24f,  0.90f, 0.035f, 24f,  0.64f, 0.076f, 19f,  0.42f, 0.060f, 22f),
    oklchTheme("After Dark", "after-dark", 0.14f, 0.110f, 277f, 0.18f, 0.080f, 277f, 0.90f, 0.035f, 277f, 0.60f, 0.090f, 285f, 0.40f, 0.075f, 285f),
    oklchTheme("Forest",     "forest",     0.12f, 0.055f, 153f, 0.16f, 0.040f, 153f, 0.90f, 0.035f, 153f, 0.80f, 0.182f, 152f, 0.44f, 0.050f, 153f),
    oklchTheme("Sky",        "sky",        0.14f, 0.055f, 243f, 0.18f, 0.040f, 243f, 0.90f, 0.035f, 243f, 0.75f, 0.139f, 233f, 0.42f, 0.050f, 243f),
    oklchTheme("Clays",      "clays",      0.13f, 0.065f, 46f,  0.17f, 0.050f, 46f,  0.90f, 0.035f, 46f,  0.67f, 0.157f, 58f,  0.42f, 0.060f, 46f),
    oklchTheme("Stones",     "stones",     0.12f, 0.005f, 34f,  0.16f, 0.003f, 34f,  0.90f, 0.035f, 34f,  0.55f, 0.023f, 264f, 0.36f, 0.005f, 34f),
    oklchTheme(
        "Dark", "dark",
        0.3033f, 0.016f, 252.42f,   // base-100
        0.2526f, 0.014f, 253.1f,    // base-200
        0.97807f, 0.029f, 256.847f, // base-content
        0.64f, 0.076f, 19f,         // primary
        0.71f, 0.024f, 255f,        // dim
        0.64f, 0.135f, 15f,         // accent
    ),
)

fun appThemeByKey(key: String): AppTheme = ALL_THEMES.firstOrNull { it.key == key } ?: ALL_THEMES.first()

/**
 * Mirrors the web picker's "System" entry. Not a palette of its own: a
 * request to follow the OS.
 */
const val SYSTEM_THEME_KEY = "system"

// The pair "system" resolves to -- the two themes actually named light and
// dark. Only these two are picked automatically; every other palette here is
// a named thing the user chose.
private const val SYSTEM_LIGHT_KEY = "light"
private const val SYSTEM_DARK_KEY = "dark"

/**
 * Resolve a stored theme key to a palette, given whether the OS is in night
 * mode. This overload exists for the home screen widgets, which build
 * RemoteViews from a Context with no composition to read.
 */
fun appThemeForKey(key: String?, systemInDark: Boolean): AppTheme =
    if (key == null || key == SYSTEM_THEME_KEY) {
        appThemeByKey(if (systemInDark) SYSTEM_DARK_KEY else SYSTEM_LIGHT_KEY)
    } else {
        appThemeByKey(key)
    }

/**
 * Resolve a stored theme key to a palette. [SYSTEM_THEME_KEY] follows the OS
 * and re-resolves when it flips, because isSystemInDarkTheme() is read during
 * composition.
 */
@Composable
fun appThemeForKey(key: String?): AppTheme = appThemeForKey(key, isSystemInDarkTheme())

/** Night mode off a Context, for the widgets' non-Compose resolution. */
fun Context.systemInDarkMode(): Boolean =
    resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
        Configuration.UI_MODE_NIGHT_YES

/** What the picker marks as selected: "System" while following. */
fun themeLabel(key: String?, resolved: AppTheme): String =
    if (key == null || key == SYSTEM_THEME_KEY) "System" else resolved.name

val LocalAppTheme = compositionLocalOf { ALL_THEMES.first() }
