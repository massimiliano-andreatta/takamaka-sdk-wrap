import 'package:takamaka_sdk_wrap/models/auth/tkm_notification_response.dart';

class TkmMockGenerate {
  static List<TkmNotificationResponse> getNotifications() {
    List<Map<String, dynamic>> mockNotifications = [
      {
        "id": 1,
        "title": "Welcome to our platform",
        "subTitle": "We are glad to have you!",
        "body": """
          <h1>Welcome!</h1>
          <p>Explore our <strong>amazing features</strong> to make the most out of your experience.</p>
          <ul>
            <li>Feature 1: Easy navigation</li>
            <li>Feature 2: Customizable settings</li>
          </ul>
        """,
        "linkUrl": null
      },
      {
        "id": 2,
        "title": "Check this out",
        "subTitle": "A new feature awaits!",
        "body": null,
        "linkUrl": "https://takamaka.io/"
      },
      {
        "id": 3,
        "title": "System Maintenance",
        "subTitle": "Scheduled maintenance notice",
        "body": null,
        "linkUrl": null
      },
      {
        "id": 4,
        "title": "Exclusive Offer",
        "subTitle": "Save on your next purchase",
        "body": """
          <h2>Exclusive Offer!</h2>
          <p>Use code <strong>SAVE15</strong> to enjoy a 15% discount on your next purchase.</p>
          <p>Offer valid until <em>November 30</em>. Don't miss it!</p>
        """,
        "linkUrl": null
      },
      {
        "id": 5,
        "title": "New Updates Available",
        "subTitle": "Upgrade to version 3.0",
        "body": null,
        "linkUrl": "https://takamaka.io/"
      },
      {
        "id": 6,
        "title": "Holiday Sale",
        "subTitle": "Get ready for amazing deals",
        "body": """
          <h2>Holiday Sale is Here!</h2>
          <p>Our biggest sale of the year starts tomorrow.</p>
          <p><strong>Don't miss out</strong> on exclusive discounts up to <span style="color:red;">50% off</span>!</p>
        """,
        "linkUrl": null
      },
      {
        "id": 7,
        "title": "Reminder",
        "subTitle": "Complete your profile",
        "body": null,
        "linkUrl": null
      }
    ];

    // Converte la lista di mappe in una lista di oggetti TkmNotificationResponse
    return mockNotifications
        .map((e) => TkmNotificationResponse.fromJson(e))
        .toList();
  }
}