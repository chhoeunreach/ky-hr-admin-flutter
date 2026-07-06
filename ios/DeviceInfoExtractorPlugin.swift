import Foundation
import UIKit
import Vision
import Flutter

@objc class DeviceInfoExtractorPlugin: NSObject, FlutterPlugin {
    
    private struct TextLine {
        let text: String
        let confidence: Float
        let boundingBox: CGRect // normalized to image coordinates (Vision uses normalized)
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "device_info_extractor/extract", binaryMessenger: registrar.messenger())
        let instance = DeviceInfoExtractorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "extract":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["imageBytes"] as? FlutterStandardTypedData,
                  let uiImage = UIImage(data: bytes.data) else {
                result(FlutterError(code: "bad-args", message: "Missing or invalid imageBytes", details: nil))
                return
            }
            extract(from: uiImage) { info in
                result([
                    "modelName": info.modelName as Any,
                    "modelNumber": info.modelNumber as Any,
                    "serialNumber": info.serialNumber as Any,
                    "capacityGB": info.capacityGB as Any,
                    "imei": info.imei as Any
                ])
            }
        case "generateQRCode":
            guard let args = call.arguments as? [String: Any],
                  let payload = args["payload"] as? [String: Any],
                  let png = generateQRCode(from: payload) else {
                result(FlutterError(code: "qr-generate-failed", message: "Could not generate QR", details: nil))
                return
            }
            result(FlutterStandardTypedData(bytes: png))
        case "decodeQRCode":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["imageBytes"] as? FlutterStandardTypedData,
                  let uiImage = UIImage(data: bytes.data) else {
                result(FlutterError(code: "bad-args", message: "Missing imageBytes", details: nil))
                return
            }
            decodeQRCode(from: uiImage) { json in
                if let json = json {
                    result(json)
                } else {
                    result(FlutterError(code: "qr-decode-failed", message: "No QR or invalid payload", details: nil))
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private struct ExtractedInfo {
        var modelName: String?
        var modelNumber: String?
        var serialNumber: String?
        var capacityGB: String?
        var imei: String?
    }

    private func extract(from image: UIImage, completion: @escaping (ExtractedInfo) -> Void) {
        guard let cg = image.cgImage else {
            completion(ExtractedInfo())
            return
        }

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self = self else { return }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            let lines: [TextLine] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return TextLine(text: candidate.string,
                                confidence: candidate.confidence,
                                boundingBox: obs.boundingBox)
            }
            
            let filtered = lines.filter { $0.confidence >= 0.35 }
            let filteredUpper = filtered.map { $0.text }.joined(separator: "\n").uppercased()
            let justStrings = filtered.map { $0.text }
            
            var info = ExtractedInfo()
            info.modelName = self.extractModelName(filteredUpper, lines: justStrings, geo: filtered)
            info.modelNumber = self.extractModelNumber(filteredUpper, lines: justStrings, geo: filtered)
            info.serialNumber = self.extractSerialNumber(filteredUpper, lines: justStrings, geo: filtered)
            info.capacityGB = self.extractCapacity(filteredUpper, lines: justStrings, geo: filtered)
            info.imei = self.extractIMEI(filteredUpper)
            
            completion(info)
        }
        
        request.recognitionLanguages = ["en-US", "en-GB"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        if #available(iOS 16.0, *) {
            request.minimumTextHeight = 0.02
        }

        let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgImagePropertyOrientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(ExtractedInfo())
            }
        }
    }

    // MARK: - Parsing helpers

    private func extractModelName(_ full: String, lines: [String], geo: [TextLine]) -> String? {
        // First try geometry: same row, value on the right of the label
        if let val = valueFollowingLabel(["model name"], lines: lines, geo: geo) {
            let upper = val.uppercased()
            if !isDisallowedLabelText(upper) && isLikelyDeviceName(val) { return val }
        }
        // Linear fallback
        if let val = valueFollowingLabelLinear(["model name"], lines: lines) {
            let upper = val.uppercased()
            if !isDisallowedLabelText(upper) && isLikelyDeviceName(val) { return val }
        }
        // Heuristic: any line starting with an Apple device family name
        if let guess = lines.first(where: { isLikelyDeviceName($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) {
            return guess.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Regex last resort
        if let match = firstMatch(in: full, pattern: #"(iPhone|iPad|iPod)(?:\s+[A-Za-z0-9]+){1,4}"#) {
            return match
        }
        return nil
    }

    private func extractModelNumber(_ full: String, lines: [String], geo: [TextLine]) -> String? {
        if let match = firstMatch(in: full, pattern: #"\b[A-Z0-9]{5,}/[A-Z]\b"#) {
            return match
        }
        if let val = valueFollowingLabel(["model number", "model no", "model no."], lines: lines, geo: geo) {
            if let m = firstMatch(in: val.uppercased(), pattern: #"\b[A-Z0-9]{5,}/[A-Z]\b"#) { return m }
            return val
        }
        if let val = valueFollowingLabelLinear(["model number", "model no", "model no."], lines: lines) {
            if let m = firstMatch(in: val.uppercased(), pattern: #"\b[A-Z0-9]{5,}/[A-Z]\b"#) { return m }
            return val
        }
        return nil
    }

    private func extractSerialNumber(_ full: String, lines: [String], geo: [TextLine]) -> String? {
        if let match = firstMatch(in: full, pattern: #"\b[A-Z0-9]{10,12}\b"#) {
            return match
        }
        if let val = valueFollowingLabel(["serial number", "serial", "s/n"], lines: lines, geo: geo) {
            return val
        }
        return valueFollowingLabelLinear(["serial number", "serial", "s/n"], lines: lines)
    }

    private func extractCapacity(_ full: String, lines: [String], geo: [TextLine]) -> String? {
        // Normalize full to uppercase for regex matching to allow "128 Gb" or "128GB"
        let fullUpper = full.uppercased()
        if let match = firstMatch(in: fullUpper, pattern: #"\b(64|128|256|512|1024)\s?GB\b"#) {
            return match.replacingOccurrences(of: " ", with: "")
        }
        if let val = valueFollowingLabel(["capacity", "storage"], lines: lines, geo: geo) {
            return val.uppercased().replacingOccurrences(of: " ", with: "")
        }
        if let val = valueFollowingLabelLinear(["capacity", "storage"], lines: lines) {
            return val.uppercased().replacingOccurrences(of: " ", with: "")
        }
        return nil
    }

    private func extractIMEI(_ full: String) -> String? {
        return firstMatch(in: full, pattern: #"\b\d{15}\b"#)
    }

    private func valueFollowingLabel(_ keys: [String], lines: [String], geo: [TextLine]) -> String? {
        let upperKeys = keys.map { $0.uppercased() }
        let pairs: [(text: String, geo: TextLine)] = zip(lines.map { $0.uppercased() }, geo).map { ($0, $1) }
        for (index, pair) in pairs.enumerated() {
            if upperKeys.contains(where: { pair.text.contains($0) }) {
                let labelBox = pair.geo.boundingBox
                // Phase 1: same row, to the right
                var sameRowCandidates: [(idx: Int, line: TextLine, hDist: CGFloat)] = []
                for (i, p) in pairs.enumerated() {
                    let box = p.geo.boundingBox
                    // Consider roughly same vertical band
                    let sameRow = abs((box.midY) - (labelBox.midY)) <= 0.03
                    let toRight = box.midX > labelBox.midX
                    if sameRow && toRight {
                        let dist = box.minX - labelBox.maxX
                        sameRowCandidates.append((i, p.geo, dist))
                    }
                }
                for cand in sameRowCandidates.sorted(by: { $0.hDist < $1.hDist }) {
                    let valueText = geo[cand.idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if valueText.isEmpty { continue }
                    let upper = valueText.uppercased()
                    if isDisallowedLabelText(upper) { continue }
                    return valueText
                }
                // Phase 2: next line below, overlapping horizontally
                var belowCandidates: [(idx: Int, line: TextLine, vDist: CGFloat)] = []
                for (i, p) in pairs.enumerated() where i > index {
                    let box = p.geo.boundingBox
                    let isBelow = box.minY < labelBox.minY
                    let horizontalOverlap = min(box.maxX, labelBox.maxX) - max(box.minX, labelBox.minX)
                    let minWidth = min(box.width, labelBox.width)
                    let overlapRatio = minWidth > 0 ? (horizontalOverlap / minWidth) : 0
                    if isBelow && overlapRatio > 0.4 {
                        let dist = abs(box.minY - labelBox.minY)
                        belowCandidates.append((i, p.geo, dist))
                    }
                }
                for cand in belowCandidates.sorted(by: { $0.vDist < $1.vDist }) {
                    let valueText = geo[cand.idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if valueText.isEmpty { continue }
                    let upper = valueText.uppercased()
                    if isDisallowedLabelText(upper) { continue }
                    return valueText
                }
            }
        }
        return nil
    }

    private func valueFollowingLabelLinear(_ keys: [String], lines: [String]) -> String? {
        let upperLines = lines.map { $0.uppercased() }
        let upperKeys = keys.map { $0.uppercased() }
        for (i, line) in upperLines.enumerated() {
            if upperKeys.contains(where: { line.contains($0) }) {
                for j in (i+1)..<upperLines.count {
                    let candidate = upperLines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                    if candidate.isEmpty { continue }
                    if upperKeys.contains(where: { candidate.contains($0) }) { continue }
                    return candidate
                }
            }
        }
        return nil
    }

    private func isDisallowedLabelText(_ upper: String) -> Bool {
        let disallowed = ["MODEL NAME", "MODEL NUMBER", "MODEL", "SERIAL", "CAPACITY", "STORAGE", "IMEI", "IMEI2"]
        return disallowed.contains(where: { upper.contains($0) })
    }

    private func isLikelyDeviceName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("iPhone") || t.hasPrefix("iPad") || t.hasPrefix("iPod")
    }

    private func generateQRCode(from json: [String: Any], scale: CGFloat = 6.0) -> Data? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        let ui = UIImage(cgImage: cg)
        return ui.pngData()
    }

    private func decodeQRCode(from image: UIImage, completion: @escaping ([String: Any]?) -> Void) {
        guard let cg = image.cgImage else { completion(nil); return }
        let request = VNDetectBarcodesRequest { req, _ in
            guard let results = req.results as? [VNBarcodeObservation] else { completion(nil); return }
            for obs in results {
                // Prefer QR code payloads
                if #available(iOS 15.0, *) {
                    if obs.symbology == .QR, let payload = obs.payloadStringValue,
                       let data = payload.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        completion(json)
                        return
                    }
                } else {
                    if obs.symbology.rawValue == VNBarcodeSymbology.QR.rawValue, let payload = obs.payloadStringValue,
                       let data = payload.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        completion(json)
                        return
                    }
                }
            }
            completion(nil)
        }
        if #available(iOS 15.0, *) {
            request.revision = VNDetectBarcodesRequestRevision3
            request.symbologies = [.QR]
        } else {
            request.symbologies = [VNBarcodeSymbology.QR]
        }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgImagePropertyOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch { completion(nil) }
        }
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let r = Range(match.range, in: text) {
            return String(text[r])
        }
        return nil
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
