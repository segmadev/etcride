# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter deferred components — Play Core classes referenced by Flutter engine
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep model classes from being stripped (JSON serialisation)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.etclogistics.etc_ride_driver.** { *; }
