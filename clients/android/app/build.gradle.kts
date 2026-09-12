plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Bumped by hand for a real release; the build metadata after it comes
// from CI.
val baseVersion = "0.1.0"

android {
    namespace = "io.neiam.apolloscrib"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "io.neiam.apolloscrib"
        // Smartspacer itself requires 12, and the foreground service type
        // declarations below are 14-era. 31 keeps the manifest honest.
        minSdk = 31
        targetSdk = 36
        // Android refuses an update whose versionCode isn't higher than
        // what's installed, and F-Droid orders versions by it — so a
        // hardcoded 1 means no phone ever sees a second release. It also
        // means every CI build publishes the same filename with
        // different bytes, which the registry correctly refuses with a
        // 409.
        //
        // The CI run number is monotonic and needs no state kept
        // anywhere. Local builds stay at 1, which is fine: they are
        // never published.
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "").toIntOrNull() ?: 1

        // The commit is what you want when someone reports a bug
        // against a build. Local builds just say "dev".
        versionName = "$baseVersion+" + ((System.getenv("GITHUB_SHA") ?: "dev").take(7))
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        // The launcher overlay interface is AIDL, and AGP leaves that off by
        // default now.
        aidl = true
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    lint {
        // `assembleRelease` is a packaging step here, not a review gate.
        //
        // lintVital doubles the release build and fails for reasons that
        // have nothing to do with the code: lint throws on JDK 25 with
        // only the version string ("25.0.4.1") as the error, so a release
        // built on a modern local JDK fails while the same commit builds
        // fine in the container's JDK.
        //
        // Lint still runs on demand: ./gradlew :app:lint
        checkReleaseBuilds = false
    }
    packaging {
        resources {
            excludes += "META-INF/INDEX.LIST"
            excludes += "META-INF/io.netty.versions.properties"
        }
    }
}

dependencies {
    implementation(libs.smartspacer.sdk.plugin)
    implementation(libs.hivemq.mqtt.client)
    implementation(libs.kotlinx.serialization.json)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)

    debugImplementation(libs.androidx.compose.ui.tooling)
    testImplementation(libs.junit)
    // Pairing parses an android.net.Uri; Robolectric is what makes that a
    // unit test rather than an instrumented one.
    testImplementation(libs.robolectric)
    testImplementation(libs.kotlinx.serialization.json)
}
