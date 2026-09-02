package io.neiam.apolloscrib.targets

/**
 * The Targets Smartspacer can add, one class per source type.
 *
 * They are separate classes because Smartspacer keys everything off the
 * provider's authority: separate authorities are what let a user add transit
 * and bikeshare independently, and see them named apart in the picker. All
 * three are four lines, which is the point -- the work lives in the renderers.
 */
class GtfsTargetProvider : ApollosTargetProvider() {
    override val renderer = GtfsRenderer
}

class GbfsTargetProvider : ApollosTargetProvider() {
    override val renderer = GbfsRenderer
}

class WeatherTargetProvider : ApollosTargetProvider() {
    override val renderer = WeatherRenderer
}
