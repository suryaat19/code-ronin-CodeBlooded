import Flutter
import UIKit
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, MFMessageComposeViewControllerDelegate {
    
    private var smsResult: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let controller = window?.rootViewController as! FlutterViewController
        let smsChannel = FlutterMethodChannel(
            name: "com.fallsense/sms",
            binaryMessenger: controller.binaryMessenger
        )
        
        smsChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            if call.method == "sendDirectSms" {
                guard let args = call.arguments as? [String: String],
                      let phone = args["phone"],
                      let message = args["message"] else {
                    result(FlutterError(code: "INVALID_ARGS",
                                       message: "Phone and message required",
                                       details: nil))
                    return
                }
                
                self.sendSMS(phone: phone, message: message, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func sendSMS(phone: String, message: String, result: @escaping FlutterResult) {
        guard MFMessageComposeViewController.canSendText() else {
            result(FlutterError(code: "NOT_AVAILABLE",
                               message: "SMS not available on this device",
                               details: nil))
            return
        }
        
        self.smsResult = result
        
        let composeVC = MFMessageComposeViewController()
        composeVC.messageComposeDelegate = self
        composeVC.recipients = [phone]
        composeVC.body = message
        
        DispatchQueue.main.async {
            if let rootVC = self.window?.rootViewController {
                rootVC.present(composeVC, animated: true, completion: nil)
            }
        }
    }
    
    // MFMessageComposeViewControllerDelegate
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true) {
            switch result {
            case .sent:
                self.smsResult?(true)
            case .cancelled:
                self.smsResult?(FlutterError(code: "CANCELLED",
                                             message: "User cancelled SMS",
                                             details: nil))
            case .failed:
                self.smsResult?(FlutterError(code: "FAILED",
                                             message: "SMS sending failed",
                                             details: nil))
            @unknown default:
                self.smsResult?(FlutterError(code: "UNKNOWN",
                                             message: "Unknown result",
                                             details: nil))
            }
            self.smsResult = nil
        }
    }
}
