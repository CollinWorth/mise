import Flutter
import UIKit
import Vision

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

    let channel = FlutterMethodChannel(
      name: "mise/vision_ocr",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "VisionOCR")!.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeText",
            let args = call.arguments as? [String: Any],
            let imagePath = args["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let image = UIImage(contentsOfFile: imagePath),
            let cgImage = image.cgImage else {
        result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
        return
      }

      let orientation = Self.cgOrientation(from: image.imageOrientation)

      let request = VNRecognizeTextRequest { req, error in
        if let error = error {
          result(FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil))
          return
        }
        guard let observations = req.results as? [VNRecognizedTextObservation] else {
          result([[String: Any]]())
          return
        }
        // Return each line with its normalised bounding box so Flutter can
        // detect columns and reading order itself.
        // Vision coords: origin bottom-left, y increases upward → flip y.
        let lines: [[String: Any]] = observations.compactMap { obs in
          guard let candidate = obs.topCandidates(1).first else { return nil }
          let box = obs.boundingBox
          return [
            "text": candidate.string,
            "x": box.minX,
            "y": 1.0 - box.maxY,   // flip to top-left origin
            "w": box.width,
            "h": box.height,
          ]
        }
        result(lines)
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = ["en-US"]
      if #available(iOS 16.0, *) {
        request.automaticallyDetectsLanguage = true
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do { try handler.perform([request]) }
        catch { result(FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil)) }
      }
    }
  }

  private static func cgOrientation(from ui: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch ui {
    case .up:            return .up
    case .down:          return .down
    case .left:          return .left
    case .right:         return .right
    case .upMirrored:    return .upMirrored
    case .downMirrored:  return .downMirrored
    case .leftMirrored:  return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default:    return .up
    }
  }
}
