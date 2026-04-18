# ProGuard rules for Talkify Receiver App

# Keep Agora classes
-keep class io.agora.** { *; }
-keep class io.agora.rtc2.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Play Core (Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
