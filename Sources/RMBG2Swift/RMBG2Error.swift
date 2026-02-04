import Foundation

/// Errors that can occur during RMBG2 operations
public enum RMBG2Error: Error, LocalizedError {
    /// Failed to download the model from HuggingFace
    case modelDownloadFailed(underlying: Error?)

    /// Failed to load the CoreML model
    case modelLoadFailed(underlying: Error?)

    /// Failed to compile the model
    case modelCompilationFailed(underlying: Error?)

    /// Failed to process the input image
    case imageProcessingFailed(reason: String)

    /// Failed during model inference
    case inferenceError(underlying: Error?)

    /// Failed to create output image
    case outputCreationFailed(reason: String)

    /// Invalid image format or dimensions
    case invalidImage(reason: String)

    /// Cache directory creation failed
    case cacheDirectoryCreationFailed

    /// Model file not found at expected location
    case modelNotFound(path: String)

    public var errorDescription: String? {
        switch self {
        case .modelDownloadFailed(let underlying):
            if let error = underlying {
                return "Failed to download model: \(error.localizedDescription)"
            }
            return "Failed to download model"

        case .modelLoadFailed(let underlying):
            if let error = underlying {
                return "Failed to load model: \(error.localizedDescription)"
            }
            return "Failed to load model"

        case .modelCompilationFailed(let underlying):
            if let error = underlying {
                return "Failed to compile model: \(error.localizedDescription)"
            }
            return "Failed to compile model"

        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"

        case .inferenceError(let underlying):
            if let error = underlying {
                return "Inference error: \(error.localizedDescription)"
            }
            return "Inference error"

        case .outputCreationFailed(let reason):
            return "Failed to create output: \(reason)"

        case .invalidImage(let reason):
            return "Invalid image: \(reason)"

        case .cacheDirectoryCreationFailed:
            return "Failed to create cache directory"

        case .modelNotFound(let path):
            return "Model not found at: \(path)"
        }
    }
}
