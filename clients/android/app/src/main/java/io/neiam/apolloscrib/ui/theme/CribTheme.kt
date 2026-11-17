package io.neiam.apolloscrib.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import io.neiam.apolloscrib.data.Settings

/**
 * The app's own screens: the ported palette plus B612.
 *
 * Read from settings, which holds either a named palette the user picked --
 * "Her", "Forest" -- or "system", in which case it follows the OS between
 * the two named light and dark. [LocalAppTheme] carries the colours Material
 * has no slot for, such as `liveGreen` for a realtime departure.
 */
@Composable
fun CribTheme(content: @Composable () -> Unit) {
    val context = LocalContext.current
    val settings = remember { Settings(context) }
    CribTheme(theme = appThemeForKey(settings.themeKey), content = content)
}

/**
 * [clearBackground] makes Material's background transparent, so a Scaffold
 * lets the shader through; whoever asks for it paints the ground themselves,
 * behind everything -- as party² does, and as MainActivity does here.
 */
@Composable
fun CribTheme(theme: AppTheme, clearBackground: Boolean = false, content: @Composable () -> Unit) {
    val scheme = theme.toColorScheme()
        .let { if (clearBackground) it.copy(background = Color.Transparent) else it }
    CompositionLocalProvider(LocalAppTheme provides theme) {
        MaterialTheme(
            colorScheme = scheme,
            typography = CribTypography,
            content = content,
        )
    }
}
