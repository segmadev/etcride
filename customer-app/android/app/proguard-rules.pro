# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

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
