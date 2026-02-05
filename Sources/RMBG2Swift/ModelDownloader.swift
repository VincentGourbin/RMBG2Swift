import Foundation
import CoreML

/// Progress callback for model download
/// - Parameters:
///   - progress: Progress value from 0.0 to 1.0
///   - status: Human-readable status message
public typealias DownloadProgressHandler = @Sendable (Double, String) -> Void

/// Handles downloading and caching of the RMBG-2 CoreML model
///
/// The model is cached at `~/Library/Caches/models/{org}/{repo}` similar to
/// other HuggingFace model loaders like mlx-voxtral-swift.
public actor ModelDownloader {
    private let configuration: RMBG2Configuration
    private let progressHandler: DownloadProgressHandler?

    /// Creates a new model downloader
    /// - Parameters:
    ///   - configuration: The RMBG2 configuration
    ///   - progress: Optional progress callback
    public init(configuration: RMBG2Configuration, progress: DownloadProgressHandler? = nil) {
        self.configuration = configuration
        self.progressHandler = progress
    }

    /// Gets the model files configuration for the current variant
    private var modelFiles: Constants.ModelFiles {
        switch configuration.modelVariant {
        case .full: return .full
        case .quantized: return .quantized
        }
    }

    /// Gets the URL to the compiled model, downloading if necessary
    /// - Returns: URL to the compiled .mlmodelc directory
    public func getCompiledModelURL() async throws -> URL {
        // If custom model URL is provided, use it directly
        if let customURL = configuration.modelURL {
            return try await compileModelIfNeeded(at: customURL)
        }

        // Get cache directory
        let cacheDir = try getCacheDirectory()

        // Check if compiled model exists in cache
        let compiledModelURL = cacheDir.appendingPathComponent(modelFiles.compiledFilename)

        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            await reportProgress(1.0, "Using cached model")
            return compiledModelURL
        }

        // Check if mlpackage exists but not compiled
        let packageURL = cacheDir.appendingPathComponent(modelFiles.packageFilename)

        if FileManager.default.fileExists(atPath: packageURL.path) {
            await reportProgress(0.5, "Compiling cached model...")
            return try await compileModel(at: packageURL, to: compiledModelURL)
        }

        // Download and compile the model
        let downloadedPackageURL = try await downloadModel(to: cacheDir)
        return try await compileModel(at: downloadedPackageURL, to: compiledModelURL)
    }

    /// Downloads the model from HuggingFace
    private func downloadModel(to cacheDir: URL) async throws -> URL {
        let packageURL = cacheDir.appendingPathComponent(modelFiles.packageFilename)

        await reportProgress(0.0, "Downloading model...")

        // HuggingFace provides a way to download folders as zip
        // For mlpackage, we download as a zip file
        guard let downloadURL = URL(string: "https://huggingface.co/\(Constants.huggingFaceRepo)/resolve/main/\(modelFiles.packageFilename).zip") else {
            throw RMBG2Error.modelDownloadFailed(underlying: nil)
        }

        // Create a download task with progress tracking
        let (tempURL, response) = try await downloadWithProgress(from: downloadURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RMBG2Error.modelDownloadFailed(underlying: nil)
        }

        // Handle different response codes
        if httpResponse.statusCode == 404 {
            // Try alternative download method - download individual files
            return try await downloadModelFiles(to: cacheDir)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RMBG2Error.modelDownloadFailed(underlying: nil)
        }

        await reportProgress(0.7, "Extracting model...")

        // Move downloaded file to cache
        let zipURL = cacheDir.appendingPathComponent("\(modelFiles.packageFilename).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: zipURL)

        // Unzip the model
        try await unzipModel(from: zipURL, to: cacheDir)

        // Clean up zip file
        try? FileManager.default.removeItem(at: zipURL)

        await reportProgress(0.9, "Model extracted")

        return packageURL
    }

    /// Downloads model files individually (fallback method)
    private func downloadModelFiles(to cacheDir: URL) async throws -> URL {
        await reportProgress(0.1, "Downloading model files...")

        let packageURL = cacheDir.appendingPathComponent(modelFiles.packageFilename)
        let dataDir = packageURL.appendingPathComponent("Data").appendingPathComponent("com.apple.CoreML")

        // Create directory structure
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // Download Manifest.json
        let manifestURL = URL(string: "\(Constants.modelBaseURL)/\(modelFiles.packageFilename)/Manifest.json")!
        let (manifestData, _) = try await URLSession.shared.data(from: manifestURL)
        try manifestData.write(to: packageURL.appendingPathComponent("Manifest.json"))

        await reportProgress(0.3, "Downloading model weights...")

        // Download model.mlmodel
        let modelFileURL = URL(string: "\(Constants.modelBaseURL)/\(modelFiles.packageFilename)/Data/com.apple.CoreML/model.mlmodel")!
        let (modelData, _) = try await URLSession.shared.data(from: modelFileURL)
        try modelData.write(to: dataDir.appendingPathComponent("model.mlmodel"))

        await reportProgress(0.6, "Downloading weights...")

        // Download weights (may be in a weights directory or as a single file)
        let weightsDir = dataDir.appendingPathComponent("weights")
        try? FileManager.default.createDirectory(at: weightsDir, withIntermediateDirectories: true)

        // Try to download weight.bin (common format)
        if let weightURL = URL(string: "\(Constants.modelBaseURL)/\(modelFiles.packageFilename)/Data/com.apple.CoreML/weights/weight.bin") {
            do {
                let (weightData, _) = try await URLSession.shared.data(from: weightURL)
                try weightData.write(to: weightsDir.appendingPathComponent("weight.bin"))
            } catch {
                // Weight file might not exist or have different name
            }
        }

        await reportProgress(0.9, "Model files downloaded")

        return packageURL
    }

    /// Downloads a file with progress tracking
    private func downloadWithProgress(from url: URL) async throws -> (URL, URLResponse) {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        return (tempURL, response)
    }

    /// Unzips the model package
    private func unzipModel(from zipURL: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", zipURL.path, "-d", destination.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RMBG2Error.modelDownloadFailed(underlying: nil)
        }
    }

    /// Compiles the model if needed
    private func compileModelIfNeeded(at url: URL) async throws -> URL {
        // If it's already a compiled model, return it
        if url.pathExtension == "mlmodelc" {
            return url
        }

        // Compile to cache directory
        let cacheDir = try getCacheDirectory()
        let compiledURL = cacheDir.appendingPathComponent(modelFiles.compiledFilename)

        // Check if already compiled
        if FileManager.default.fileExists(atPath: compiledURL.path) {
            return compiledURL
        }

        return try await compileModel(at: url, to: compiledURL)
    }

    /// Compiles the model to the specified location
    private func compileModel(at sourceURL: URL, to destinationURL: URL) async throws -> URL {
        await reportProgress(0.9, "Compiling model...")

        // Remove existing compiled model if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            let compiledURL = try await MLModel.compileModel(at: sourceURL)

            // Move to cache directory
            try FileManager.default.moveItem(at: compiledURL, to: destinationURL)

            await reportProgress(1.0, "Model ready")

            return destinationURL
        } catch {
            throw RMBG2Error.modelCompilationFailed(underlying: error)
        }
    }

    /// Gets the cache directory, creating it if necessary
    /// Cache location: ~/Library/Caches/models/{org}/{repo}
    private func getCacheDirectory() throws -> URL {
        if let customDir = configuration.cacheDirectory {
            if !FileManager.default.fileExists(atPath: customDir.path) {
                try FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
            }
            return customDir
        }

        let cacheDir = Constants.defaultCacheDirectory

        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            } catch {
                throw RMBG2Error.cacheDirectoryCreationFailed
            }
        }

        return cacheDir
    }

    /// Reports progress to the handler
    private func reportProgress(_ progress: Double, _ status: String) async {
        progressHandler?(progress, status)
    }

    /// Clears the cached model files
    /// - Returns: True if cache was cleared successfully
    public func clearCache() throws -> Bool {
        let cacheDir = try getCacheDirectory()

        if FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.removeItem(at: cacheDir)
            return true
        }

        return false
    }

    /// Returns the cache directory URL
    public func getCacheDirectoryURL() throws -> URL {
        return try getCacheDirectory()
    }
}
