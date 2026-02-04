import Foundation
import CoreML
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Image processing utilities for RMBG2
enum ImageProcessing {

    /// Resizes an image to the model input size (1024x1024)
    /// - Parameters:
    ///   - image: The source CGImage
    ///   - size: Target size (default: model input size)
    /// - Returns: Resized CGImage or nil on failure
    static func resize(_ image: CGImage, to size: Int = Constants.modelInputSize) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context?.makeImage()
    }

    /// Creates an MLMultiArray from a CGImage with ImageNet normalization
    /// - Parameter image: The source CGImage (should be 1024x1024)
    /// - Returns: MLMultiArray with shape [1, 3, H, W] in NCHW format
    static func createMultiArray(from image: CGImage) throws -> MLMultiArray {
        let width = image.width
        let height = image.height

        // Create MLMultiArray with shape [1, 3, H, W]
        let array = try MLMultiArray(
            shape: [1, 3, NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        )

        // Get pixel data
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RMBG2Error.imageProcessingFailed(reason: "Failed to create graphics context")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            throw RMBG2Error.imageProcessingFailed(reason: "Failed to get pixel data")
        }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // ImageNet normalization
        let mean = Constants.normalizationMean
        let std = Constants.normalizationStd

        // Fill array (NCHW format)
        for c in 0..<3 {
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIdx = (y * width + x) * 4
                    let value = Float(pixels[pixelIdx + c]) / 255.0
                    let normalized = (value - mean[c]) / std[c]

                    let arrayIdx = c * height * width + y * width + x
                    array[arrayIdx] = NSNumber(value: normalized)
                }
            }
        }

        return array
    }

    /// Creates a grayscale mask image from model output
    /// - Parameters:
    ///   - array: The MLMultiArray output from the model
    ///   - size: The output size
    /// - Returns: Grayscale CGImage representing the mask
    static func createMaskImage(from array: MLMultiArray, size: Int) throws -> CGImage {
        let count = size * size
        var pixels = [UInt8](repeating: 0, count: count)

        for i in 0..<count {
            // Sigmoid is already applied, values should be 0-1
            var value = array[i].floatValue
            // Clamp to 0-1
            value = max(0, min(1, value))
            pixels[i] = UInt8(value * 255)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: size,
                height: size,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to create mask image")
        }

        return image
    }

    /// Resizes a mask image to match the original image dimensions
    /// - Parameters:
    ///   - mask: The mask CGImage
    ///   - targetSize: The target size
    /// - Returns: Resized mask CGImage
    static func resizeMask(_ mask: CGImage, to targetSize: CGSize) -> CGImage? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Applies a grayscale mask as an alpha channel to the original image
    /// - Parameters:
    ///   - image: The original CGImage
    ///   - mask: The grayscale mask CGImage
    /// - Returns: CGImage with the mask applied as alpha channel
    static func applyMask(to image: CGImage, mask: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)

        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Get mask data
        guard let maskContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        maskContext.draw(mask, in: rect)

        guard let maskData = maskContext.data else { return nil }
        let maskPixels = maskData.bindMemory(to: UInt8.self, capacity: width * height)

        // Apply mask as alpha
        for i in 0..<(width * height) {
            pixels[i * 4 + 3] = maskPixels[i]
        }

        return context.makeImage()
    }
}

// MARK: - Platform-specific extensions

#if canImport(AppKit)
public extension NSImage {
    /// Converts NSImage to CGImage
    func toCGImage() -> CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Creates NSImage from CGImage
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif

#if canImport(UIKit)
public extension UIImage {
    /// Converts UIImage to CGImage
    func toCGImage() -> CGImage? {
        cgImage
    }

    /// Creates UIImage from CGImage
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage)
    }
}
#endif
