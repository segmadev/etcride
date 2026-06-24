// STUB — replace this file by running:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=etcride
// in the driver-app directory.
//
// Until then the app compiles and runs normally; FCM is silently disabled.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'STUB',
    appId: 'STUB',
    messagingSenderId: 'STUB',
    projectId: 'etcride',
    storageBucket: 'etcride.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'STUB',
    appId: 'STUB',
    messagingSenderId: 'STUB',
    projectId: 'etcride',
    storageBucket: 'etcride.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'STUB',
    appId: 'STUB',
    messagingSenderId: 'STUB',
    projectId: 'etcride',
    storageBucket: 'etcride.appspot.com',
    iosBundleId: 'com.etclogistics.etcRideDriver',
  );
}
