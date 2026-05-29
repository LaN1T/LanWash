# Flutter ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver
-dontwarn android.**

# Play Core / Deferred Components (Flutter references these but they're optional)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# PDF / Printing
-keep class com.itextpdf.** { *; }
-keep class com.shockwave.** { *; }
-dontwarn com.itextpdf.**

# File picker / share_plus
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
