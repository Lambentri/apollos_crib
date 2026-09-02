package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.types.SourceType

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

class TidalTargetProvider : ApollosTargetProvider() {
    override val renderer = TidalRenderer
}

class AqiTargetProvider : ApollosTargetProvider() {
    override val renderer = AqiRenderer
}

class EphemTargetProvider : ApollosTargetProvider() {
    override val renderer = EphemRenderer
}

class CalendarTargetProvider : ApollosTargetProvider() {
    override val renderer = CalendarRenderer
}

class PollenTargetProvider : ApollosTargetProvider() {
    override val renderer = PollenRenderer
}

class DroughtTargetProvider : ApollosTargetProvider() {
    override val renderer = DroughtRenderer
}

class GitlabTargetProvider : ApollosTargetProvider() {
    override val renderer = GitlabRenderer
}

class GithubTargetProvider : ApollosTargetProvider() {
    override val renderer = GithubRenderer
}

// The passthroughs share one renderer class, so each names the instance the
// registry built for its type rather than declaring another object.
class CronosTargetProvider : ApollosTargetProvider() {
    override val renderer = Targets.rendererFor(SourceType.Cronos)!!
}

class PackagesTargetProvider : ApollosTargetProvider() {
    override val renderer = Targets.rendererFor(SourceType.Packages)!!
}

class ConstTargetProvider : ApollosTargetProvider() {
    override val renderer = Targets.rendererFor(SourceType.Const)!!
}
