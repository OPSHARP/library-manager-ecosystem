# Flutter-specific ProGuard rules

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature

# Keep Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable
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

# Keep R8 from stripping interface info needed for reflection
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**
-dontwarn com.baseflow.permissionhandler.AppSettingsManager$OpenAppSettingsSuccessCallback
-dontwarn com.baseflow.permissionhandler.AppSettingsManager

# Don't warn about missing classes from optional dependencies
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn com.google.android.play.core.**

# Google Sign-In (google_sign_in Flutter plugin)
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class * extends com.google.android.gms.common.api.Result { *; }

# Keep Google Sign-In callback classes used via reflection
-keep class * implements com.google.android.gms.common.api.internal.ApiKey { *; }
-keep class * extends com.google.android.gms.common.api.internal.BaseImplementation$ApiMethodImpl { *; }

# ─── Google Mobile Ads (AdMob) — google_mobile_ads ───────────────────────────
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.android.gms.measurement.** { *; }
-dontwarn com.google.android.gms.measurement.**
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.internal.ads.**

# ─── In-App Updates (Play Core) — in_app_update ──────────────────────────────
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.appupdate.internal.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.install.model.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ─── flutter_secure_storage (Android Keystore-backed storage) ────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ─── local_auth (BiometricPrompt) ─────────────────────────────────────────────
-keep class com.example.flutter_local_auth.** { *; }
-dontwarn com.example.flutter_local_auth.**

# ─── geolocator ───────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── image_picker / file_picker / share_plus / connectivity_plus ─────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ─── in_app_purchase (Google Play Billing) ───────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
-keep class com.google.android.play.core.billing.** { *; }
-dontwarn com.google.android.play.core.billing.**

# ─── Keep okhttp/okio if pulled in transitively (image upload / analytics) ────
-dontwarn okhttp3.**
-dontwarn okio.**

