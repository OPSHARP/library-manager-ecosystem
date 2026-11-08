import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not available for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmVze8PbCFJa76NjWZMHGhhFWW5Af8UMM',
    appId: '1:412683622526:web:4fd1723331fae6d662e02f',
    messagingSenderId: '412683622526',
    projectId: 'mynotebookpro-edec0',
    authDomain: 'mynotebookpro-edec0.firebaseapp.com',
    storageBucket: 'mynotebookpro-edec0.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmVze8PbCFJa76NjWZMHGhhFWW5Af8UMM',
    appId: '1:412683622526:android:4fd1723331fae6d662e02f',
    messagingSenderId: '412683622526',
    projectId: 'mynotebookpro-edec0',
    storageBucket: 'mynotebookpro-edec0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmVze8PbCFJa76NjWZMHGhhFWW5Af8UMM',
    appId: '1:412683622526:ios:4fd1723331fae6d662e02f',
    messagingSenderId: '412683622526',
    projectId: 'mynotebookpro-edec0',
    storageBucket: 'mynotebookpro-edec0.firebasestorage.app',
    iosBundleId: 'com.librarymanager.student',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBmVze8PbCFJa76NjWZMHGhhFWW5Af8UMM',
    appId: '1:412683622526:ios:4fd1723331fae6d662e02f',
    messagingSenderId: '412683622526',
    projectId: 'mynotebookpro-edec0',
    storageBucket: 'mynotebookpro-edec0.firebasestorage.app',
    iosBundleId: 'com.librarymanager.student',
  );
}
