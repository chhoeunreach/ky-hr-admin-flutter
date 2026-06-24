import UIKit
import Flutter
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

    private func logPush(_ message: String) {
        print("[PUSH][iOS] \(message)")
    }

    private func syncBadgeIfMissing(from userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any], aps["badge"] == nil else {
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber += 1
        }
    }
    
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            logPush("Firebase configured natively for production-safe APNs registration")
        }

        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }
        WorkmanagerPlugin.registerPeriodicTask(
            withIdentifier: "offline_image_upload_periodic_task",
            frequency: NSNumber(value: 15 * 60)
        )

        GeneratedPluginRegistrant.register(with: self)
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        logPush("Requested APNs remote notification registration")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        logPush("APNs device token registered: \(token)")
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logPush("Failed to register for APNs: \(error.localizedDescription)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    override func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable : Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        logPush("Received remote notification: \(userInfo)")
        syncBadgeIfMissing(from: userInfo)
        super.application(
          application,
          didReceiveRemoteNotification: userInfo,
          fetchCompletionHandler: completionHandler
        )
    }

    override func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logPush("Will present foreground notification: \(notification.request.content.userInfo)")
        syncBadgeIfMissing(from: notification.request.content.userInfo)

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logPush("Firebase registration token updated: \(fcmToken ?? "missing")")
    }
}
