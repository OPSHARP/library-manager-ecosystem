# ─────────────────────────────────────────────────────────────────────────────
#  LM Students — ProGuard / R8 rules (release minification + obfuscation)
#  Applied on top of the default proguard-android-optimize.txt rules.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Flutter core & plugins glue ─────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# ─── Firebase ────────────────────────────────────────────────────────────────
# Firebase AARs bundle their own consumer-rules.pro.
# Do NOT use blanket "-keep class com.google.firebase.** { *; }" as that
# disables R8 shrinking, obfuscation, and optimization across all of Firebase.
-dontwarn com.google.firebase.**
-dontwarn io.invertase.firebase.**
-dontwarn com.google.firebase.firestore.**
-dontwarn io.grpc.**

# ─── Google Play Services & Google Sign-In ───────────────────────────────────
# Google Play Services AARs bundle their own consumer-rules.pro.
# Keep only reflection/callback classes required by google_sign_in.
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class * extends com.google.android.gms.common.api.Result { *; }
-keep class * implements com.google.android.gms.common.api.internal.ApiKey { *; }
-keep class * extends com.google.android.gms.common.api.internal.BaseImplementation$ApiMethodImpl { *; }
-dontwarn com.google.android.gms.**

# ─── Google Mobile Ads (AdMob) ───────────────────────────────────────────────
# Keep public SDK entry points for Google Mobile Ads while allowing R8 to
# shrink, obfuscate, and optimize internal classes.
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep public class com.google.ads.** {
    public *;
}
-dontwarn com.google.ads.**
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.android.gms.measurement.**
-dontwarn com.google.android.gms.internal.ads.**

# ─── ML Kit & CameraX (mobile_scanner) ───────────────────────────────────────
# ML Kit and CameraX bundle their own consumer-rules.pro for service loaders.
# Suppress warnings without blanket keeping { *; } so R8 can optimize.
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.vision.**
-dontwarn androidx.camera.**

# ─── In-App Updates (Play Core) ──────────────────────────────────────────────
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.appupdate.internal.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.install.model.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# ─── flutter_local_notifications ─────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class androidx.core.app.NotificationCompat** { *; }

# ─── flutter_secure_storage (Android Keystore-backed storage) ────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ─── geolocator ───────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── permission_handler ──────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**
-dontwarn com.baseflow.permissionhandler.AppSettingsManager$OpenAppSettingsSuccessCallback
-dontwarn com.baseflow.permissionhandler.AppSettingsManager

# ─── connectivity_plus ────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ─── Reflection-friendly attributes ───────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ─── Android framework contracts used reflectively ───────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ─── Suppress warnings from optional/transitive deps absent at runtime ───────
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn androidx.work.**
