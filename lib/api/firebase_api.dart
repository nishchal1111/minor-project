import 'package:firebase_messaging/firebase_messaging.dart';
Future<void>handleBackgroundMessage(RemoteMessage message)  async{
print('Title: ${message.notification?.title}');
print('Body: ${message.notification?.body}');

print('Payload: ${message.data}');

}
class FirebaseApi {
  final firebaseMessaging = FirebaseMessaging.instance;
Future<void>initNotification() async{
  await firebaseMessaging.requestPermission();
  
  final fCMToken = await firebaseMessaging.getToken();
  print('Token: $fCMToken');

 
}

}