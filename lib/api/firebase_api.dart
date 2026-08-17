import 'package:firebase_messaging/firebase_messaging.dart';
Future<void>handleBackgroundMessage(RemoteMessage message)  async{
('Title: ${message.notification?.title}');
('Body: ${message.notification?.body}');

('Payload: ${message.data}');

}
class FirebaseApi {
  final firebaseMessaging = FirebaseMessaging.instance;
Future<void>initNotification() async{
  await firebaseMessaging.requestPermission();
  
  final fCMToken = await firebaseMessaging.getToken();
  ('Token: $fCMToken');

 
}

}