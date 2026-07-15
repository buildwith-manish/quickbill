# Flutter-aware ProGuard rules.
# Keep the Flutter engine and Dart AOT symbols — stripping them breaks the app.

# Keep everything in the flutter engine.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift uses reflection for SQLite type converters.
-keep class drift.** { *; }
-keep class * extends drift.runtime.** { *; }

# Keep generated Drift database class.
-keep class com.quickbill.quickbill.** { *; }

# sqlite3_flutter_libs native bindings.
-keep class com.sqlite3_flutter_libs.** { *; }

# Don't warn about missing optional classes from packages we use.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
