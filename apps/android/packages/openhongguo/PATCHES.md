# Patches on openhongguo 0.2.0 (Flutter)

Vendored from pub.dev `openhongguo` 0.2.0 for DramaRed Android.

## Changes

1. `android/build.gradle.kts`: apply `org.jetbrains.kotlin.android`, remove broken
   top-level `kotlin { compilerOptions … }` that failed under Flutter's plugin
   classpath; use `kotlinOptions.jvmTarget = 17`; `compileSdk = 35`.
2. iOS binding trees omitted in this vendor copy (Android-only consumer).

Upstream disclaimer and Apache-2.0 license still apply.
