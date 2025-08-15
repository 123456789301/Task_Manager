import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  // Replace with your Firebase Web app options (from Firebase console)
  static FirebaseOptions get webOptions => const FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}
