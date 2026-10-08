import Flutter
import PhotosUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SealPicker") {
      SealPicker.register(with: registrar)
    }
  }
}

/// 印影 / ロゴ picker. PHPickerViewController shows the photo library out of
/// process, so the app never asks for photo library access and Info.plist
/// needs no NSPhotoLibraryUsageDescription.
final class SealPicker: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private var pending: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "jp.mitsumori.app/seal_picker",
      binaryMessenger: registrar.messenger()
    )
    let instance = SealPicker()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pick" else {
      result(FlutterMethodNotImplemented)
      return
    }
    if pending != nil {
      result(FlutterError(code: "busy", message: "picker already open", details: nil))
      return
    }
    guard let presenter = SealPicker.topViewController() else {
      result(FlutterError(code: "no_view", message: "no view controller", details: nil))
      return
    }
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    pending = result
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider,
      provider.canLoadObject(ofClass: UIImage.self)
    else {
      finish(nil)
      return
    }
    provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
      let png = (object as? UIImage).flatMap { SealPicker.downscaledPNG($0, maxSide: 600) }
      DispatchQueue.main.async { self?.finish(png) }
    }
  }

  private func finish(_ png: Data?) {
    let result = pending
    pending = nil
    if let png = png {
      result?(FlutterStandardTypedData(bytes: png))
    } else {
      result?(nil)
    }
  }

  private static func downscaledPNG(_ image: UIImage, maxSide: CGFloat) -> Data? {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }
    let scale = min(1, maxSide / max(size.width, size.height))
    let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: target, format: format)
    let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    return resized.pngData()
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
      ?? scenes.flatMap { $0.windows }.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
