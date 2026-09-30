#if canImport(Vision)
import CareerDomain
import Foundation
import Vision

/// Local Japanese text recognition with Vision. Pages are processed one at a
/// time off the cooperative pool, in reading order, preserving confidence and
/// bounding boxes for the review step.
public struct VisionTextRecognitionService: TextRecognitionService {
    public init() {}

    public func recognize(pages: [Data]) async throws -> [RecognizedTextLine] {
        var lines: [RecognizedTextLine] = []
        for (index, page) in pages.enumerated() {
            if Task.isCancelled { throw EngineError.canceled }
            lines += try await Self.recognizePage(page, index: index)
        }
        if Task.isCancelled { throw EngineError.canceled }
        return lines
    }

    private static func recognizePage(_ data: Data, index: Int) async throws -> [RecognizedTextLine] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try perform(data, pageIndex: index))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func perform(_ data: Data, pageIndex: Int) throws -> [RecognizedTextLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
        } catch {
            throw EngineError.unavailable("Text recognition could not process the page")
        }

        let observations = (request.results ?? []).sorted { lhs, rhs in
            let left = (rowKey(lhs.boundingBox.midY), lhs.boundingBox.minX)
            let right = (rowKey(rhs.boundingBox.midY), rhs.boundingBox.minX)
            return left < right
        }
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return RecognizedTextLine(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                pageIndex: pageIndex,
                boundingBox: NormalizedRect(
                    x: Double(box.minX), y: Double(box.minY),
                    width: Double(box.width), height: Double(box.height)
                )
            )
        }
    }

    /// Buckets lines into rows, top of the page first, so slight vertical
    /// jitter between words on one line does not reorder them.
    private static func rowKey(_ midY: CGFloat) -> Int {
        Int(((1 - Double(midY)) / 0.012).rounded(.down))
    }
}
#endif
