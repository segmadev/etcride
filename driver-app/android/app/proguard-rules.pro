# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep model classes from being stripped (JSON serialisation)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.etclogistics.etc_ride_driver.** { *; }
