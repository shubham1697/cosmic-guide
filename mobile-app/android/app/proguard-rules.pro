# R8/ProGuard rules for the release build.
# The Flutter and Firebase Gradle plugins contribute their own rules; these
# cover the plugins that reflect over classes at runtime.

# flutter_local_notifications serialises scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn com.dexterous.**

# Gson type tokens rely on generic signatures surviving shrinking.
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }

# Firebase messaging services are referenced from the manifest only.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
