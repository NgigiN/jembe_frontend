# Flutter defaults rely on R8 for tree shaking. Keep only the rules we need.

# Preserve Flutter plugins' entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep generated registrant so plugins can register.
-keep class **.GeneratedPluginRegistrant { *; }

# Retain classes referenced via reflection by the logger.
-keep class com.orhanobut.logger.** { *; }

# Retain models serialized/deserialized via Gson/JSON.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Flutter deferred components reference Play Core optionally; not bundled in release.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Reduce size by stripping debugging info from release builds.
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

