import Foundation
import RMBG2Swift
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

/// RMBG2 CLI - Command-line tool for background removal
@main
struct RMBG2CLI {
    static func main() async {
        print("RMBG2 - Background Removal CLI")
        print("==============================\n")

        let args = CommandLine.arguments

        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let command = args[1]

        switch command {
        case "process", "-p":
            await processImage()
        case "cache":
            await handleCache()
        case "help", "-h", "--help":
            printUsage()
        default:
            // Treat as image path for convenience
            await processImage(imagePath: command)
        }
    }

    static func processImage(imagePath: String? = nil) async {
        let args = CommandLine.arguments
        let inputPath: String
        let outputPath: String

        if let path = imagePath {
            inputPath = path
            outputPath = args.count > 2 ? args[2] : generateOutputPath(from: path)
        } else {
            guard args.count >= 3 else {
                print("Error: Missing input image path")
                printUsage()
                exit(1)
            }
            inputPath = args[2]
            outputPath = args.count > 3 ? args[3] : generateOutputPath(from: inputPath)
        }

        do {
            print("Loading model...")
            let rmbg = try await RMBG2 { progress, status in
                print("  \(status) (\(Int(progress * 100))%)")
            }

            print("\nLoading image: \(inputPath)")

            #if canImport(AppKit)
            guard let inputImage = NSImage(contentsOfFile: inputPath) else {
                print("Error: Could not load image from \(inputPath)")
                exit(1)
            }

            guard let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("Error: Could not convert image to CGImage")
                exit(1)
            }
            #else
            print("Error: CLI only supports macOS")
            exit(1)
            #endif

            print("Image size: \(cgImage.width)x\(cgImage.height)")
            print("\nRemoving background...")

            let result = try await rmbg.removeBackground(from: cgImage)

            print("Inference time: \(String(format: "%.2f", result.inferenceTime * 1000)) ms")

            // Save output
            print("\nSaving output: \(outputPath)")
            try saveImage(result.image, to: outputPath)

            // Save mask
            let maskPath = outputPath.replacingOccurrences(of: ".png", with: "_mask.png")
            try saveImage(result.mask, to: maskPath)
            print("Mask saved: \(maskPath)")

            print("\nDone!")

        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }

    static func handleCache() async {
        let args = CommandLine.arguments

        guard args.count >= 3 else {
            print("Cache commands:")
            print("  cache info   - Show cache location and status")
            print("  cache clear  - Clear cached model files")
            exit(0)
        }

        let subcommand = args[2]

        switch subcommand {
        case "info":
            let downloader = ModelDownloader(configuration: .default)
            do {
                let cacheDir = try await downloader.getCacheDirectoryURL()
                print("Cache directory: \(cacheDir.path)")

                let compiledModelPath = cacheDir.appendingPathComponent("RMBG-2-native.mlmodelc").path
                let packagePath = cacheDir.appendingPathComponent("RMBG-2-native.mlpackage").path

                if FileManager.default.fileExists(atPath: compiledModelPath) {
                    print("Compiled model: Present")
                } else if FileManager.default.fileExists(atPath: packagePath) {
                    print("Model package: Present (not compiled)")
                } else {
                    print("Model: Not downloaded")
                }
            } catch {
                print("Error: \(error)")
            }

        case "clear":
            let downloader = ModelDownloader(configuration: .default)
            do {
                let cleared = try await downloader.clearCache()
                if cleared {
                    print("Cache cleared successfully")
                } else {
                    print("Cache was already empty")
                }
            } catch {
                print("Error clearing cache: \(error)")
            }

        default:
            print("Unknown cache command: \(subcommand)")
        }
    }

    static func printUsage() {
        print("""
        Usage: rmbg2-cli <input_image> [output_image]
               rmbg2-cli process <input_image> [output_image]
               rmbg2-cli cache <info|clear>

        Commands:
          process   Remove background from an image
          cache     Manage cached model files
          help      Show this help message

        Examples:
          rmbg2-cli photo.jpg                    # Output: photo_nobg.png
          rmbg2-cli photo.jpg result.png         # Custom output path
          rmbg2-cli cache info                   # Show cache location
          rmbg2-cli cache clear                  # Clear cached model

        The model is automatically downloaded on first use.
        Cache location: ~/Library/Caches/models/VincentGourbin/RMBG-2-CoreML/

        License: This tool uses RMBG-2.0 by BRIA AI (CC BY-NC 4.0)
        Commercial use requires a license from BRIA AI: https://bria.ai
        """)
    }

    static func generateOutputPath(from inputPath: String) -> String {
        let url = URL(fileURLWithPath: inputPath)
        let name = url.deletingPathExtension().lastPathComponent
        let directory = url.deletingLastPathComponent().path
        return "\(directory)/\(name)_nobg.png"
    }

    static func saveImage(_ image: CGImage, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "RMBG2CLI", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create image destination"
            ])
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "RMBG2CLI", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to save image"
            ])
        }
    }
}
