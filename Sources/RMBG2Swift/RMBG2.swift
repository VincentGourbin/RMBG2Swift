import Foundation
import CoreML
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Result of a background removal operation
public struct RMBG2Result: Sendable {
    /// The image with transparent background
    public let image: CGImage

    /// The grayscale mask (white = foreground, black = background)
    public let mask: CGImage

    /// Time taken for model inference in seconds
    public let inferenceTime: TimeInterval
}

/// RMBG2 - Background Removal using BRIA AI's RMBG-2.0 Model
///
/// This class provides high-level APIs for removing backgrounds from images
/// using the RMBG-2.0 CoreML model optimized for Apple Neural Engine.
///
/// ## Simple Usage
/// ```swift
/// let rmbg = try await RMBG2()
/// let result = try await rmbg.removeBackground(from: image)
/// ```
///
/// ## With Progress Tracking
/// ```swift
/// let rmbg = try await RMBG2 { progress, status in
///     print("\(status): \(Int(progress * 100))%")
/// }
/// ```
///
/// ## License
/// This uses the RMBG-2.0 model by BRIA AI (CC BY-NC 4.0).
/// Commercial use requires a license from BRIA AI: https://bria.ai/contact-us
///
public final class RMBG2: @unchecked Sendable {
    private let model: MLModel
    private let configuration: RMBG2Configuration

    /// Creates a new RMBG2 instance with default configuration
    /// - Parameter progress: Optional progress callback during model download/compilation
    /// - Throws: RMBG2Error if model loading fails
    public convenience init(progress: DownloadProgressHandler? = nil) async throws {
        try await self.init(configuration: .default, progress: progress)
    }

    /// Creates a new RMBG2 instance with custom configuration
    /// - Parameters:
    ///   - configuration: Configuration options for compute units, model path, etc.
    ///   - progress: Optional progress callback during model download/compilation
    /// - Throws: RMBG2Error if model loading fails
    public init(configuration: RMBG2Configuration, progress: DownloadProgressHandler? = nil) async throws {
        self.configuration = configuration

        // Download/locate the model
        let downloader = ModelDownloader(configuration: configuration, progress: progress)
        let modelURL = try await downloader.getCompiledModelURL()

        // Load the model
        let config = MLModelConfiguration()
        config.computeUnits = configuration.computeUnits

        do {
            self.model = try await MLModel.load(contentsOf: modelURL, configuration: config)
        } catch {
            throw RMBG2Error.modelLoadFailed(underlying: error)
        }
    }

    /// Removes the background from an image
    /// - Parameter image: The input CGImage
    /// - Returns: RMBG2Result containing the masked image, mask, and timing info
    /// - Throws: RMBG2Error if processing fails
    public func removeBackground(from image: CGImage) async throws -> RMBG2Result {
        let originalSize = CGSize(width: image.width, height: image.height)

        // Resize to model input size
        guard let resizedImage = ImageProcessing.resize(image) else {
            throw RMBG2Error.imageProcessingFailed(reason: "Failed to resize input image")
        }

        // Create input array
        let inputArray = try ImageProcessing.createMultiArray(from: resizedImage)

        // Run inference
        let startTime = CFAbsoluteTimeGetCurrent()

        let inputFeature = MLFeatureValue(multiArray: inputArray)
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["input": inputFeature])

        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: inputProvider)
        } catch {
            throw RMBG2Error.inferenceError(underlying: error)
        }

        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime

        // Get the main output mask (output_3 is full resolution 1024x1024)
        guard let outputFeature = prediction.featureValue(for: "output_3"),
              let outputArray = outputFeature.multiArrayValue else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to get model output")
        }

        // Get output size from shape
        let outputSize = outputArray.shape[2].intValue

        // Create mask image
        let mask = try ImageProcessing.createMaskImage(from: outputArray, size: outputSize)

        // Resize mask to original image size
        guard let resizedMask = ImageProcessing.resizeMask(mask, to: originalSize) else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to resize mask")
        }

        // Apply mask to original image
        guard let outputImage = ImageProcessing.applyMask(to: image, mask: resizedMask) else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to apply mask")
        }

        return RMBG2Result(
            image: outputImage,
            mask: resizedMask,
            inferenceTime: inferenceTime
        )
    }

    /// Generates only the mask without applying it
    /// - Parameter image: The input CGImage
    /// - Returns: Grayscale mask CGImage
    /// - Throws: RMBG2Error if processing fails
    public func generateMask(from image: CGImage) async throws -> CGImage {
        let originalSize = CGSize(width: image.width, height: image.height)

        // Resize to model input size
        guard let resizedImage = ImageProcessing.resize(image) else {
            throw RMBG2Error.imageProcessingFailed(reason: "Failed to resize input image")
        }

        // Create input array
        let inputArray = try ImageProcessing.createMultiArray(from: resizedImage)

        // Run inference
        let inputFeature = MLFeatureValue(multiArray: inputArray)
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["input": inputFeature])

        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: inputProvider)
        } catch {
            throw RMBG2Error.inferenceError(underlying: error)
        }

        // Get the main output mask
        guard let outputFeature = prediction.featureValue(for: "output_3"),
              let outputArray = outputFeature.multiArrayValue else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to get model output")
        }

        let outputSize = outputArray.shape[2].intValue
        let mask = try ImageProcessing.createMaskImage(from: outputArray, size: outputSize)

        // Resize to original size
        guard let resizedMask = ImageProcessing.resizeMask(mask, to: originalSize) else {
            throw RMBG2Error.outputCreationFailed(reason: "Failed to resize mask")
        }

        return resizedMask
    }

    /// Applies a custom mask to an image
    /// - Parameters:
    ///   - mask: Grayscale mask CGImage
    ///   - image: The image to apply the mask to
    /// - Returns: Image with mask applied as alpha channel
    public func applyMask(_ mask: CGImage, to image: CGImage) -> CGImage? {
        // Ensure mask is same size as image
        let targetSize = CGSize(width: image.width, height: image.height)
        let resizedMask: CGImage

        if mask.width != image.width || mask.height != image.height {
            guard let rm = ImageProcessing.resizeMask(mask, to: targetSize) else {
                return nil
            }
            resizedMask = rm
        } else {
            resizedMask = mask
        }

        return ImageProcessing.applyMask(to: image, mask: resizedMask)
    }

    /// Removes background from multiple images
    /// - Parameter images: Array of CGImages to process
    /// - Returns: Array of RMBG2Results
    /// - Throws: RMBG2Error if any processing fails
    public func removeBackground(from images: [CGImage]) async throws -> [RMBG2Result] {
        var results: [RMBG2Result] = []
        results.reserveCapacity(images.count)

        for image in images {
            let result = try await removeBackground(from: image)
            results.append(result)
        }

        return results
    }
}

// MARK: - Platform-specific convenience methods

#if canImport(AppKit)
public extension RMBG2 {
    /// Removes the background from an NSImage
    /// - Parameter image: The input NSImage
    /// - Returns: RMBG2Result containing the masked image, mask, and timing info
    /// - Throws: RMBG2Error if processing fails
    func removeBackground(from image: NSImage) async throws -> RMBG2Result {
        guard let cgImage = image.toCGImage() else {
            throw RMBG2Error.invalidImage(reason: "Could not convert NSImage to CGImage")
        }
        return try await removeBackground(from: cgImage)
    }

    /// Generates only the mask from an NSImage
    /// - Parameter image: The input NSImage
    /// - Returns: Grayscale mask as NSImage
    /// - Throws: RMBG2Error if processing fails
    func generateMask(from image: NSImage) async throws -> NSImage {
        guard let cgImage = image.toCGImage() else {
            throw RMBG2Error.invalidImage(reason: "Could not convert NSImage to CGImage")
        }
        let mask = try await generateMask(from: cgImage)
        return NSImage(cgImage: mask)
    }
}
#endif

#if canImport(UIKit)
public extension RMBG2 {
    /// Removes the background from a UIImage
    /// - Parameter image: The input UIImage
    /// - Returns: RMBG2Result containing the masked image, mask, and timing info
    /// - Throws: RMBG2Error if processing fails
    func removeBackground(from image: UIImage) async throws -> RMBG2Result {
        guard let cgImage = image.toCGImage() else {
            throw RMBG2Error.invalidImage(reason: "Could not convert UIImage to CGImage")
        }
        return try await removeBackground(from: cgImage)
    }

    /// Generates only the mask from a UIImage
    /// - Parameter image: The input UIImage
    /// - Returns: Grayscale mask as UIImage
    /// - Throws: RMBG2Error if processing fails
    func generateMask(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.toCGImage() else {
            throw RMBG2Error.invalidImage(reason: "Could not convert UIImage to CGImage")
        }
        let mask = try await generateMask(from: cgImage)
        return UIImage(cgImage: mask)
    }
}
#endif
