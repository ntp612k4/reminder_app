// Web implementation using the browser Notification API.
import 'dart:html' as html;

Future<void> showWebNotification(String title, String body) async {
  try {
    final permission = html.Notification.permission;
    if (permission == 'granted') {
      html.Notification(title, body: body);
      return;
    }

    final p = await html.Notification.requestPermission();
    if (p == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (e) {
    // ignore errors on web
  }
}
