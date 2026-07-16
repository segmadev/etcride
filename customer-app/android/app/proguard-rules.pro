# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter deferred components — Play Core classes referenced by Flutter engine
# but not bundled in the APK; suppress R8 warnings instead of crashing the build
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutterwave / Monnify WebView-based SDKs — keep JS interfaces
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep model classes from being stripped (JSON serialisation)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.etclogistics.etc_ride_customer.** { *; }
