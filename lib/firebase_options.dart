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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGvZC6OrdqBPvrMiO-WgCWUD0bV0Ox_Lg',
    appId: '1:828440824665:android:b674b630030d2ff7a4da48',
    messagingSenderId: '828440824665',
    projectId: 'jobease-edevs',
    storageBucket: 'jobease-edevs.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDTjqCwO1WDE1yz3RuslFWtKmqinR-5v5k',
    appId: '1:828440824665:ios:b6435bd5146bcbaea4da48',
    messagingSenderId: '828440824665',
    projectId: 'jobease-edevs',
    storageBucket: 'jobease-edevs.firebasestorage.app',
    androidClientId: '828440824665-7r2rre7rci5j70e67baki17554iik81a.apps.googleusercontent.com',
    iosClientId: '828440824665-3sfl3dm09190id0j1a1lrromvofltgqi.apps.googleusercontent.com',
    iosBundleId: 'com.shailesh.alljobopen',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKDhRUYtxy7fMQF3SP59xm5uLPzT3UevQ',
    appId: '1:828440824665:web:d932c82ab3cfdc8fa4da48',
    messagingSenderId: '828440824665',
    projectId: 'jobease-edevs',
    authDomain: 'jobease-edevs.firebaseapp.com',
    storageBucket: 'jobease-edevs.firebasestorage.app',
    measurementId: 'G-F4JND5LTFZ',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDTjqCwO1WDE1yz3RuslFWtKmqinR-5v5k',
    appId: '1:828440824665:ios:b6435bd5146bcbaea4da48',
    messagingSenderId: '828440824665',
    projectId: 'jobease-edevs',
    storageBucket: 'jobease-edevs.firebasestorage.app',
    androidClientId: '828440824665-7r2rre7rci5j70e67baki17554iik81a.apps.googleusercontent.com',
    iosClientId: '828440824665-3sfl3dm09190id0j1a1lrromvofltgqi.apps.googleusercontent.com',
    iosBundleId: 'com.shailesh.alljobopen',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAKDhRUYtxy7fMQF3SP59xm5uLPzT3UevQ',
    appId: '1:828440824665:web:d87bd5571c5ad6a1a4da48',
    messagingSenderId: '828440824665',
    projectId: 'jobease-edevs',
    authDomain: 'jobease-edevs.firebaseapp.com',
    storageBucket: 'jobease-edevs.firebasestorage.app',
    measurementId: 'G-XTQBHTQ7HE',
  );

}