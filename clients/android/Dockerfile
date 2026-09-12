# Builds and signs the release APK.
#
# In a container rather than on the runner, so the runner needs docker
# and nothing else, and a developer can reproduce exactly what CI did
# without installing an SDK.
#
#     docker buildx build \
#       --target android-export \
#       --secret id=keystore,src=./release.jks \
#       --secret id=keystore_password,src=./keystore.pass \
#       --output type=local,dest=./apk \
#       --progress=plain \
#       --file clients/android/Dockerfile clients/android
#
# Run from the repository root. The build context is `clients/android`, not the
# repository: the app needs nothing from outside it, and the root
# .dockerignore in several of these repos excludes `android/` so the
# service image doesn't drag the Gradle wrapper and SDK caches along.
# With a repo-root context BuildKit is handed a tree with the app
# filtered out of it, and the COPY below fails as a bare glob error
# with no step log to explain itself.

# JDK 21 rather than 17, and a current cmdline-tools: AGP 9.2 / Gradle
# 9.4 here, compiling against android-36.1. The 2024-era tools pinned
# by the other apps in this family predate that platform.
ARG JDK_IMAGE=eclipse-temurin:21-jdk

FROM ${JDK_IMAGE} AS sdk

# Pinned. `…_latest.zip` is a moving target under a cache that has no
# way to notice it moved.
ARG CMDLINE_TOOLS=commandlinetools-linux-13114758_latest.zip
ARG ANDROID_PLATFORM=36.1
ARG BUILD_TOOLS=36.1.0

ENV ANDROID_HOME=/opt/android-sdk \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
 && curl -fsSL "https://dl.google.com/android/repository/${CMDLINE_TOOLS}" -o /tmp/tools.zip \
 && unzip -q /tmp/tools.zip -d "${ANDROID_HOME}/cmdline-tools" \
 && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
 && rm /tmp/tools.zip

ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# `yes |` because sdkmanager prompts per licence and there is no
# non-interactive flag that covers all of them.
RUN yes | sdkmanager --licenses > /dev/null \
 && sdkmanager --install \
      "platforms;android-${ANDROID_PLATFORM}" \
      "build-tools;${BUILD_TOOLS}" \
      "platform-tools" > /dev/null

# ── dependencies ─────────────────────────────────────────────────────
#
# Build files only, so the ~200 MB of Gradle and Maven downloads cache
# as one layer that survives every change to the Kotlin sources.

FROM sdk AS deps

WORKDIR /src
COPY gradle ./gradle
COPY gradlew settings.gradle.kts build.gradle.kts gradle.properties ./
COPY app/build.gradle.kts ./app/

RUN echo "sdk.dir=${ANDROID_HOME}" > local.properties

# A task that resolves the whole dependency graph without needing the
# sources. `--no-daemon` because a daemon outliving the RUN is just a
# process the image has to reap.
RUN ./gradlew --no-daemon :app:dependencies --configuration releaseRuntimeClasspath > /dev/null \
 || echo "dependency warm-up failed; the build below will fetch them"

# ── build ────────────────────────────────────────────────────────────

FROM deps AS build

ARG BUILD_TOOLS=36.1.0
COPY app ./app

RUN ./gradlew --no-daemon :app:assembleRelease

# Sign as a separate step from Gradle so the keystore never reaches a
# build script, a Gradle cache, or an image layer. BuildKit secrets are
# mounted for the life of one RUN and are not committed.
#
# zipalign before apksigner, not after: aligning rewrites offsets, and
# doing it to an already-signed APK invalidates the v2 signature that
# covers them.
#
# No --key-pass. apksigner reads each `file:` password as a *sequential*
# read from that file, so passing the same one-line file to both
# --ks-pass and --key-pass makes the second read hit EOF:
#
#   Failed to read Key "…" password: end of file reached
#
# Omitted, the key password defaults to the store password, which is
# what PKCS12 keystores use anyway.
RUN --mount=type=secret,id=keystore,target=/tmp/release.jks \
    --mount=type=secret,id=keystore_password,target=/tmp/keystore.pass \
    set -eu; \
    tools="${ANDROID_HOME}/build-tools/${BUILD_TOOLS}"; \
    unsigned=app/build/outputs/apk/release/app-release-unsigned.apk; \
    mkdir -p /out; \
    "${tools}/zipalign" -p -f 4 "$unsigned" /tmp/aligned.apk; \
    "${tools}/apksigner" sign \
      --ks /tmp/release.jks \
      --ks-pass "file:/tmp/keystore.pass" \
      --out /out/app-release.apk \
      /tmp/aligned.apk; \
    "${tools}/apksigner" verify --print-certs /out/app-release.apk

# ── export ───────────────────────────────────────────────────────────
#
# FROM scratch, so `--output type=local` lands the APK and nothing else.

FROM scratch AS android-export
COPY --from=build /out/app-release.apk /
