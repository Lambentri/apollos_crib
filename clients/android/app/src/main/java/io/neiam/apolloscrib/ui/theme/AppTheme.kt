package io.neiam.apolloscrib.ui.theme

import android.graphics.Color as AndroidColor
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
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
) = AppTheme(
    name = name, key = key,
    bg        = oklchToColor(bgL, bgC, bgH),
    cardBg    = oklchToColor(cardL, cardC, cardH),
    content   = oklchToColor(contentL, contentC, contentH),
    primary   = oklchToColor(primaryL, primaryC, primaryH),
    dim       = oklchToColor(dimL, dimC, dimH),
    accent    = oklchToColor(0.96f, 0.058f, 96f),
    liveGreen = oklchToColor(0.75f, 0.15f, 145f),
)

/** Plain Material 3 light defaults — handy escape hatch when the OKLCh
 * palettes feel like overkill. Hex values come straight from M3's baseline
 * light theme so it looks at home alongside Android stock components. */
private object MaterialLight {
    val BG          = Color(0xFFFFFBFE)  // surface
    val CARD        = Color(0xFFF7F2FA)  // surfaceContainer
    val CONTENT     = Color(0xFF1D1B20)  // onSurface
    val PRIMARY     = Color(0xFF6750A4)  // primary
    val DIM         = Color(0xFF49454F)  // onSurfaceVariant
    val ACCENT      = Color(0xFF7D5260)  // tertiary
    val LIVE_GREEN  = Color(0xFF006E26)
}

val ALL_THEMES: List<AppTheme> = listOf(
    AppTheme(
        name = "Light", key = "light",
        bg = MaterialLight.BG,
        cardBg = MaterialLight.CARD,
        content = MaterialLight.CONTENT,
        primary = MaterialLight.PRIMARY,
        dim = MaterialLight.DIM,
        accent = MaterialLight.ACCENT,
        liveGreen = MaterialLight.LIVE_GREEN,
        isLight = true,
    ),
    oklchTheme("Her",        "her",        0.18f, 0.095f, 24f,  0.22f, 0.070f, 24f,  0.90f, 0.035f, 24f,  0.64f, 0.076f, 19f,  0.42f, 0.060f, 22f),
    oklchTheme("After Dark", "after-dark", 0.14f, 0.110f, 277f, 0.18f, 0.080f, 277f, 0.90f, 0.035f, 277f, 0.60f, 0.090f, 285f, 0.40f, 0.075f, 285f),
    oklchTheme("Forest",     "forest",     0.12f, 0.055f, 153f, 0.16f, 0.040f, 153f, 0.90f, 0.035f, 153f, 0.80f, 0.182f, 152f, 0.44f, 0.050f, 153f),
    oklchTheme("Sky",        "sky",        0.14f, 0.055f, 243f, 0.18f, 0.040f, 243f, 0.90f, 0.035f, 243f, 0.75f, 0.139f, 233f, 0.42f, 0.050f, 243f),
    oklchTheme("Clays",      "clays",      0.13f, 0.065f, 46f,  0.17f, 0.050f, 46f,  0.90f, 0.035f, 46f,  0.67f, 0.157f, 58f,  0.42f, 0.060f, 46f),
    oklchTheme("Stones",     "stones",     0.12f, 0.005f, 34f,  0.16f, 0.003f, 34f,  0.90f, 0.035f, 34f,  0.55f, 0.023f, 264f, 0.36f, 0.005f, 34f),
    oklchTheme("Dark",       "dark",       0.14f, 0.015f, 240f, 0.18f, 0.010f, 240f, 0.90f, 0.035f, 240f, 0.70f, 0.100f, 85f,  0.40f, 0.015f, 240f),
)

fun appThemeByKey(key: String): AppTheme = ALL_THEMES.firstOrNull { it.key == key } ?: ALL_THEMES.first()

val LocalAppTheme = compositionLocalOf { ALL_THEMES.first() }
