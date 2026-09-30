import CareerDomain
import CoreGraphics
import Foundation
import ImageIO

/// Prepares a user-selected photo for storage: center-crops to the résumé
/// photo aspect ratio (3:4), downsamples, and re-encodes as JPEG so the
/// retained portrait is small enough to synchronize.
public enum PortraitProcessor {
    public static let maximumPixelHeight = 800
    public static let storageQuality = 0.85

    public static func prepare(
        _ data: Data,
        maximumPixelHeight: Int = PortraitProcessor.maximumPixelHeight
    ) throws -> PortraitImage {
        let source = try PortraitCodec.decode(data)
        let cropped = centerCrop(source, aspect: 3.0 / 4.0)
        let scaled = downsample(cropped, maximumHeight: maximumPixelHeight)
        let encoded = try PortraitCodec.encodeJPEG(scaled, quality: storageQuality)
        return PortraitImage(data: encoded, pixelWidth: scaled.width, pixelHeight: scaled.height)
    }

    static func centerCrop(_ image: CGImage, aspect: Double) -> CGImage {
        let width = Double(image.width)
        let height = Double(image.height)
        var cropWidth = width
        var cropHeight = height
        if width / height > aspect {
            cropWidth = (height * aspect).rounded(.down)
        } else {
            cropHeight = (width / aspect).rounded(.down)
        }
        let rect = CGRect(
            x: ((width - cropWidth) / 2).rounded(.down),
            y: ((height - cropHeight) / 2).rounded(.down),
            width: cropWidth,
            height: cropHeight
        )
        return image.cropping(to: rect) ?? image
    }

    static func downsample(_ image: CGImage, maximumHeight: Int) -> CGImage {
        guard image.height > maximumHeight, maximumHeight > 0 else { return image }
        let scale = Double(maximumHeight) / Double(image.height)
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: maximumHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: maximumHeight))
        return context.makeImage() ?? image
    }
}
