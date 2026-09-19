import CallKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let callBridge = CallObserverBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterEventChannel(name: "phaseguard/phone_state", binaryMessenger: messenger)
      .setStreamHandler(callBridge)
    FlutterMethodChannel(name: "phaseguard/phone_control", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "startMonitor" || call.method == "stopMonitor" {
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
  }
}

final class CallObserverBridge: NSObject, FlutterStreamHandler, CXCallObserverDelegate {
  private let observer = CXCallObserver()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    observer.setDelegate(self, queue: nil)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    var state = "idle"
    if call.hasEnded {
      state = "idle"
    } else if !call.hasConnected && !call.isOutgoing {
      state = "ringing"
    } else {
      state = "offhook"
    }
    sink?(["state": state, "number": NSNull()])
  }
}
