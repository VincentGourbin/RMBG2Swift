import Foundation
import CoreML

/// Model variant to use for inference
public enum ModelVariant: Sendable {
    /// Full precision FP32 model (461 MB)
    /// Higher precision but larger download
    case full

    /// INT8 quantized model (233 MB) - Recommended
    /// Smaller size, optimized for ANE, equivalent quality
    case quantized
}

/// Configuration options for RMBG2
public struct RMBG2Configuration: Sendable {
    /// Model variant to use (full FP32 or quantized INT8)
    public let modelVariant: ModelVariant

    /// Compute units to use for inference
    public let computeUnits: MLComputeUnits

    /// Custom model URL (if nil, downloads from HuggingFace)
    public let modelURL: URL?

    /// Custom cache directory (if nil, uses default)
    public let cacheDirectory: URL?

    /// Creates a new configuration with the specified options
    /// - Parameters:
    ///   - modelVariant: The model variant to use. Defaults to `.quantized` (INT8, smaller and ANE optimized).
    ///   - computeUnits: The compute units to use for inference. Defaults to `.all` which enables the Apple Neural Engine (ANE).
    ///   - modelURL: Optional custom model URL. If nil, the model will be downloaded from HuggingFace.
    ///   - cacheDirectory: Optional custom cache directory. If nil, uses the default cache location.
    public init(
        modelVariant: ModelVariant = .quantized,
        computeUnits: MLComputeUnits = .all,
        modelURL: URL? = nil,
        cacheDirectory: URL? = nil
    ) {
        self.modelVariant = modelVariant
        self.computeUnits = computeUnits
        self.modelURL = modelURL
        self.cacheDirectory = cacheDirectory
    }

    /// Default configuration using quantized model with ANE
    public static let `default` = RMBG2Configuration()

    /// Configuration using full precision FP32 model
    public static let fullPrecision = RMBG2Configuration(modelVariant: .full)

    /// Configuration using CPU and GPU only (no ANE)
    public static let cpuAndGPU = RMBG2Configuration(computeUnits: .cpuAndGPU)

    /// Configuration using CPU only
    public static let cpuOnly = RMBG2Configuration(computeUnits: .cpuOnly)
}
