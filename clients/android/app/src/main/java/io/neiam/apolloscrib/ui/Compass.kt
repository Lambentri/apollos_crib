package io.neiam.apolloscrib.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.view.Surface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import io.neiam.apolloscrib.ui.theme.LocalAppTheme
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Which way the phone is pointing.
 *
 * [degrees] is clockwise from north, 0 until the first reading. [trueNorth]
 * says which north that is: the cards' bearings are true — they are computed
 * from coordinates — so a magnetic reading beside them would disagree by the
 * local declination, which is a whole compass point in New England and rather
 * more in places. Saying which one is being shown is the difference between a
 * compass and a decoration.
 */
data class Heading(val degrees: Float, val trueNorth: Boolean, val available: Boolean)

/**
 * The device's heading, while this composable is on screen and resumed.
 *
 * Unregistered when the screen is not resumed rather than only when it leaves
 * composition: a rotation vector at UI rate is a sensor running, and running
 * it behind the launcher is battery spent on a reading nobody can see.
 */
@Composable
fun rememberHeading(): State<Heading> {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val heading = remember { mutableStateOf(Heading(0f, false, false)) }

    DisposableEffect(lifecycleOwner) {
        val sensors = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val rotation = sensors?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        if (sensors == null || rotation == null) {
            // A device with no rotation vector: say so once and draw nothing,
            // rather than a dial frozen at north pretending to be a compass.
            heading.value = Heading(0f, false, false)
            return@DisposableEffect onDispose {}
        }

        val declination = declinationAt(context)

        val listener = object : SensorEventListener {
            private var smoothed: Float? = null

            override fun onSensorChanged(event: SensorEvent) {
                val magnetic = azimuthOf(event, context) ?: return
                val corrected = wrap(magnetic + (declination ?: 0f))

                // Smoothed across the shortest way round, so a reading passing
                // north does not spin the dial the long way from 359 to 1.
                val previous = smoothed
                smoothed = if (previous == null) {
                    corrected
                } else {
                    wrap(previous + shortestTurn(previous, corrected) * SMOOTHING)
                }

                heading.value = Heading(smoothed!!, declination != null, true)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }

        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME ->
                    sensors.registerListener(listener, rotation, SensorManager.SENSOR_DELAY_UI)

                Lifecycle.Event.ON_PAUSE -> sensors.unregisterListener(listener)
                else -> Unit
            }
        }

        lifecycleOwner.lifecycle.addObserver(observer)

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            sensors.unregisterListener(listener)
        }
    }

    return heading
}

/** How much of each new reading to take. Low enough to settle a shaky hand. */
private const val SMOOTHING = 0.15f

private val COMPASS_POINTS =
    listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
           "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW")

/** The sixteen-point name for a bearing, as the cards use. */
fun compassPoint(degrees: Float): String =
    COMPASS_POINTS[((wrap(degrees) / 22.5f).roundToInt()) % 16]

private fun wrap(degrees: Float): Float = ((degrees % 360f) + 360f) % 360f

// Signed difference from a to b, taking whichever way round is shorter.
private fun shortestTurn(from: Float, to: Float): Float {
    val diff = wrap(to - from)
    return if (diff > 180f) diff - 360f else diff
}

/**
 * The azimuth from a rotation vector, in the orientation the screen is held.
 *
 * Remapped by the display's rotation: without it a phone in landscape reads
 * ninety degrees out, which is the kind of wrong that looks like a broken
 * sensor rather than a missing correction.
 */
private fun azimuthOf(event: SensorEvent, context: Context): Float? {
    val matrix = FloatArray(9)
    SensorManager.getRotationMatrixFromVector(matrix, event.values)

    val display = ContextCompat.getDisplayOrDefault(context)
    val (axisX, axisY) = when (display.rotation) {
        Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
        Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
        Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
        else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
    }

    val remapped = FloatArray(9)
    if (!SensorManager.remapCoordinateSystem(matrix, axisX, axisY, remapped)) return null

    val orientation = FloatArray(3)
    SensorManager.getOrientation(remapped, orientation)

    return wrap(Math.toDegrees(orientation[0].toDouble()).toFloat())
}

/**
 * The local magnetic declination, or null when there is nowhere to compute it.
 *
 * Needs a position, and this app only holds one when location reporting has
 * been switched on. Without it the heading stays magnetic and says so, rather
 * than silently pointing a compass point off.
 */
private fun declinationAt(context: Context): Float? {
    val granted =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    if (!granted) return null

    val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null

    val last = runCatching {
        manager.allProviders
            .mapNotNull { manager.getLastKnownLocation(it) }
            .maxByOrNull { it.time }
    }.getOrNull() ?: return null

    return GeomagneticField(
        last.latitude.toFloat(),
        last.longitude.toFloat(),
        last.altitude.toFloat(),
        System.currentTimeMillis()
    ).declination
}

/**
 * A dial, the bearing in degrees, and the point it names.
 *
 * The card is what turns, not the needle. A needle swinging against a fixed
 * dial tells you where north is; a dial turning under a fixed mark tells you
 * where *you* are pointing, which is the question being asked next to a row of
 * cards saying a stop is NE of you.
 */
@Composable
fun Compass(heading: Heading, modifier: Modifier = Modifier) {
    if (!heading.available) return

    val palette = LocalAppTheme.current

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(1.dp)
    ) {
        Canvas(Modifier.size(34.dp)) { drawRose(heading.degrees, palette.dim, palette.accent) }

        Text(
            "${wrap(heading.degrees).roundToInt()}° ${compassPoint(heading.degrees)}",
            style = MaterialTheme.typography.labelSmall,
            fontFamily = FontFamily.Monospace,
            color = palette.dim
        )
    }
}

private fun DrawScope.drawRose(
    degrees: Float,
    dim: androidx.compose.ui.graphics.Color,
    accent: androidx.compose.ui.graphics.Color
) {
    val radius = size.minDimension / 2f
    val centre = Offset(size.minDimension / 2f, size.minDimension / 2f)

    drawCircle(color = dim.copy(alpha = 0.35f), radius = radius - 1f, style = Stroke(width = 1.5f))

    // The mark you read against: fixed at the top, pointing at whatever the
    // phone is pointing at.
    drawPath(
        path = Path().apply {
            moveTo(centre.x, 1.5f)
            lineTo(centre.x - 3.5f, 8f)
            lineTo(centre.x + 3.5f, 8f)
            close()
        },
        color = accent
    )

    // The card, turning under it. Negative because the world turns the other
    // way from the phone: face east and north must move to the left.
    rotate(degrees = -degrees, pivot = centre) {
        // North, and the other three cardinals as plain ticks.
        drawLine(
            color = accent,
            start = Offset(centre.x, centre.y - radius + 4f),
            end = Offset(centre.x, centre.y - radius * 0.35f),
            strokeWidth = 2f
        )

        for (point in 1..3) {
            val angle = Math.toRadians(point * 90.0)
            val outer = radius - 4f
            val inner = radius * 0.7f

            drawLine(
                color = dim,
                start = Offset(
                    centre.x + (sin(angle) * outer).toFloat(),
                    centre.y - (cos(angle) * outer).toFloat()
                ),
                end = Offset(
                    centre.x + (sin(angle) * inner).toFloat(),
                    centre.y - (cos(angle) * inner).toFloat()
                ),
                strokeWidth = 1f
            )
        }
    }
}
