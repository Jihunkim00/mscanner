# ========== FLUTTER + GOOGLE SIGN-IN R8 PROTECTION (2025) ==========

# --- Flutter plugin bridge ---
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Google Sign-In Android plugin (7.x, Pigeon generated) ---
-keep class dev.flutter.pigeon.google_sign_in_android.** { *; }
-keep class dev.flutter.plugins.googlesignin.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }

# --- Google Play services auth/common ---
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }

# --- Firebase (auth/core) ---
-keep class io.flutter.plugins.firebase.auth.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }

# --- Kotlin annotations ---
-keepclassmembers class ** {
    @org.jetbrains.annotations.NotNull *;
    @org.jetbrains.annotations.Nullable *;
}

-keepattributes *Annotation*, InnerClasses, EnclosingMethod

# --- Warnings off ---
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**
-dontwarn kotlin.**

-keep class dev.flutter.pigeon.** { *; }
