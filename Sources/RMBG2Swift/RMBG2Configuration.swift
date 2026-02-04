import Foundation
import CoreML

/// Configuration options for RMBG2
public struct RMBG2Configuration: Sendable {
    /// Compute units to use for inference
    public let computeUnits: MLComputeUnits

    /// Custom model URL (if nil, downloads from HuggingFace)
    public let modelURL: URL?

    /// Custom cache directory (if nil, uses default)
    public let cacheDirectory: URL?

    /// Creates a new configuration with the specified options
    /// - Parameters:
    ///   - computeUnits: The compute units to use for inference. Defaults to `.all` which enables the Apple Neural Engine (ANE).
    ///   - modelURL: Optional custom model URL. If nil, the model will be downloaded from HuggingFace.
    ///   - cacheDirectory: Optional custom cache directory. If nil, uses the default cache location.
    public init(
        computeUnits: MLComputeUnits = .all,
        modelURL: URL? = nil,
        cacheDirectory: URL? = nil
    ) {
        self.computeUnits = computeUnits
        self.modelURL = modelURL
        self.cacheDirectory = cacheDirectory
    }

    /// Default configuration using ANE and automatic model download
    public static let `default` = RMBG2Configuration()

    /// Configuration using CPU and GPU only (no ANE)
    public static let cpuAndGPU = RMBG2Configuration(computeUnits: .cpuAndGPU)

    /// Configuration using CPU only
    public static let cpuOnly = RMBG2Configuration(computeUnits: .cpuOnly)
}
