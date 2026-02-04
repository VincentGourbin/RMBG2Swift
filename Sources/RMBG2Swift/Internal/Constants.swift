import Foundation

/// Internal constants for RMBG2Swift
enum Constants {
    /// Model input size (1024x1024)
    static let modelInputSize = 1024

    /// HuggingFace organization
    static let huggingFaceOrg = "VincentGOURBIN"

    /// HuggingFace repository name
    static let huggingFaceRepoName = "RMBG-2-CoreML"

    /// Full HuggingFace model repository
    static let huggingFaceRepo = "\(huggingFaceOrg)/\(huggingFaceRepoName)"

    /// Model filename
    static let modelFilename = "RMBG-2-native.mlpackage"

    /// Compiled model filename
    static let compiledModelFilename = "RMBG-2-native.mlmodelc"

    /// Base URL for model download from HuggingFace
    static let modelBaseURL = "https://huggingface.co/\(huggingFaceRepo)/resolve/main"

    /// ImageNet normalization mean values (RGB)
    static let normalizationMean: [Float] = [0.485, 0.456, 0.406]

    /// ImageNet normalization standard deviation values (RGB)
    static let normalizationStd: [Float] = [0.229, 0.224, 0.225]

    /// Model version for cache invalidation
    static let modelVersion = "1.0.0"

    /// Default cache directory path (similar to mlx-voxtral-swift)
    /// Primary: ~/Library/Caches/models/{org}/{repo}
    static var defaultCacheDirectory: URL {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDir
            .appendingPathComponent("models")
            .appendingPathComponent(huggingFaceOrg)
            .appendingPathComponent(huggingFaceRepoName)
    }
}
