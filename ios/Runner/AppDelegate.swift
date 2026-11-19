import UIKit
import PhotosUI
import UniformTypeIdentifiers
import Flutter
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    private let communityVideoPicker = CommunityVideoPicker()


    private func logPush(_ message: String) {
        print("[PUSH][iOS] \(message)")
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
        if let registrar = registrar(forPlugin: "CommunityGallery") {
            let channel = FlutterMethodChannel(
                name: "cnattendance/community_gallery", binaryMessenger: registrar.messenger())
            channel.setMethodCallHandler { [weak self] call, result in
                guard call.method == "pickVideo" else {
                    result(FlutterMethodNotImplemented)
                    return
                }
                guard let self = self, var presenter = self.window?.rootViewController else {
                    result(FlutterError(code: "gallery_unavailable",
                                        message: "The photo library cannot be opened right now.", details: nil))
                    return
                }
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                self.communityVideoPicker.present(from: presenter, result: result)
            }
        }
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
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
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
        logPush("Received remote notification")
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
        if notification.request.trigger is UNPushNotificationTrigger {
            // Let FlutterFire record the delivery. Complete native presentation once.
            super.userNotificationCenter(
                center,
                willPresent: notification,
                withCompletionHandler: { _ in }
            )
        }

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


/// Video-only Photos selection without requesting access to the full library.
private final class CommunityVideoPicker: NSObject, PHPickerViewControllerDelegate {
    private var pendingResult: FlutterResult?

    func present(from presenter: UIViewController, result: @escaping FlutterResult) {
        guard pendingResult == nil else {
            result(FlutterError(code: "gallery_already_open",
                                message: "The photo library is already open.", details: nil))
            return
        }
        pendingResult = result
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            complete(nil)
            return
        }
        // The provider's temporary URL is only valid during this callback.
        // Copy it before returning so Flutter can preview and upload the video.
        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
            guard let self = self else { return }
            guard let url = url else {
                self.complete(FlutterError(code: "gallery_video_unavailable",
                    message: error?.localizedDescription ?? "The selected video could not be loaded.", details: nil))
                return
            }
            do {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("community_gallery", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let filename = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                let destination = directory.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: url, to: destination)
                self.complete(destination.path)
            } catch {
                self.complete(FlutterError(code: "gallery_video_copy_failed",
                    message: error.localizedDescription, details: nil))
            }
        }
    }

    private func complete(_ value: Any?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let result = self.pendingResult else { return }
            self.pendingResult = nil
            result(value)
        }
    }
}
