import XCTest
@testable import RMBG2Swift

final class RMBG2SwiftTests: XCTestCase {

    func testConfigurationDefaults() {
        let config = RMBG2Configuration()
        XCTAssertEqual(config.computeUnits, .all)
        XCTAssertNil(config.modelURL)
        XCTAssertNil(config.cacheDirectory)
    }

    func testConfigurationPresets() {
        let cpuOnly = RMBG2Configuration.cpuOnly
        XCTAssertEqual(cpuOnly.computeUnits, .cpuOnly)

        let cpuAndGPU = RMBG2Configuration.cpuAndGPU
        XCTAssertEqual(cpuAndGPU.computeUnits, .cpuAndGPU)
    }

    func testConstants() {
        XCTAssertEqual(Constants.modelInputSize, 1024)
        XCTAssertEqual(Constants.huggingFaceOrg, "VincentGourbin")
        XCTAssertEqual(Constants.huggingFaceRepoName, "RMBG-2-CoreML")
    }

    func testCacheDirectoryPath() {
        let cacheDir = Constants.defaultCacheDirectory
        XCTAssertTrue(cacheDir.path.contains("Library/Caches/models"))
        XCTAssertTrue(cacheDir.path.contains("VincentGourbin"))
        XCTAssertTrue(cacheDir.path.contains("RMBG-2-CoreML"))
    }

    func testErrorDescriptions() {
        let downloadError = RMBG2Error.modelDownloadFailed(underlying: nil)
        XCTAssertNotNil(downloadError.errorDescription)

        let loadError = RMBG2Error.modelLoadFailed(underlying: nil)
        XCTAssertNotNil(loadError.errorDescription)

        let processError = RMBG2Error.imageProcessingFailed(reason: "test")
        XCTAssertTrue(processError.errorDescription?.contains("test") ?? false)
    }

    // Integration tests that require the model
    // These are skipped in CI environments

    func testModelDownloaderCacheDirectory() async throws {
        let config = RMBG2Configuration()
        let downloader = ModelDownloader(configuration: config)

        let cacheDir = try await downloader.getCacheDirectoryURL()
        XCTAssertTrue(cacheDir.path.contains("models"))
    }

    // Uncomment to run full integration test (requires model download)
    /*
    func testRemoveBackgroundIntegration() async throws {
        let rmbg = try await RMBG2()

        // Create a simple test image
        let testImage = createTestImage(width: 100, height: 100)

        let result = try await rmbg.removeBackground(from: testImage)

        XCTAssertEqual(result.image.width, 100)
        XCTAssertEqual(result.image.height, 100)
        XCTAssertEqual(result.mask.width, 100)
        XCTAssertEqual(result.mask.height, 100)
        XCTAssertGreaterThan(result.inferenceTime, 0)
    }

    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Fill with a solid color
        context.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }
    */
}
