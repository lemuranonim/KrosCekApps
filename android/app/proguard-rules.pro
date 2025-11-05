# Menjaga anotasi
-keepattributes *Annotation*

# Mengabaikan warning terkait library lama (android.arch dan android.support)
-dontwarn android.arch.**
-dontwarn android.support.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# AndroidX
-dontwarn androidx.**
-keep class androidx.** { *; }
-keepattributes *Annotation*

# Jetpack Compose
-dontwarn androidx.compose.**
-keep class androidx.compose.** { *; }
-keepattributes *Annotation*
