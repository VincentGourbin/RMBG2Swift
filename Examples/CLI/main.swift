import Foundation
import CoreML
import RMBG2Swift
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

/// RMBG2 CLI - Command-line tool for background removal
@main
struct RMBG2CLI {
    static var modelVariant: ModelVariant = .quantized
    static var computeUnits: MLComputeUnits = .all

    static func main() async {
        print("RMBG2 - Background Removal CLI")
        print("==============================\n")

        var args = Array(CommandLine.arguments.dropFirst())

        // Parse --model option
        if let modelIndex = args.firstIndex(of: "--model") {
            if modelIndex + 1 < args.count {
                let variant = args[modelIndex + 1]
                switch variant {
                case "int8", "quantized":
                    modelVariant = .quantized
                case "full", "fp32":
                    modelVariant = .full
                default:
                    print("Unknown model variant: \(variant)")
                    print("Use 'int8' or 'full'")
                    exit(1)
                }
                args.remove(at: modelIndex + 1)
                args.remove(at: modelIndex)
            }
        }

        // Parse --compute option
        if let computeIndex = args.firstIndex(of: "--compute") {
            if computeIndex + 1 < args.count {
                let units = args[computeIndex + 1]
                switch units {
                case "all", "ane":
                    computeUnits = .all
                case "cpuAndGPU", "gpu":
                    computeUnits = .cpuAndGPU
                case "cpuOnly", "cpu":
                    computeUnits = .cpuOnly
                default:
                    print("Unknown compute units: \(units)")
                    print("Use 'all', 'cpuAndGPU', or 'cpuOnly'")
                    exit(1)
                }
                args.remove(at: computeIndex + 1)
                args.remove(at: computeIndex)
            }
        }

        guard args.count >= 1 else {
            printUsage()
            exit(1)
        }

        let command = args[0]

        switch command {
        case "process", "-p":
            await processImage(args: Array(args.dropFirst()))
        case "cache":
            await handleCache(args: Array(args.dropFirst()))
        case "help", "-h", "--help":
            printUsage()
        default:
            // Treat as image path for convenience
            await processImage(args: args)
        }
    }

    static func processImage(args: [String]) async {
        guard args.count >= 1 else {
            print("Error: Missing input image path")
            printUsage()
            exit(1)
        }

        let inputPath = args[0]
        let outputPath = args.count > 1 ? args[1] : generateOutputPath(from: inputPath)

        let variantName = modelVariant == .quantized ? "INT8 quantized" : "FP32 full precision"
        let computeName: String
        switch computeUnits {
        case .all: computeName = "ANE (.all)"
        case .cpuAndGPU: computeName = "CPU+GPU (.cpuAndGPU)"
        case .cpuOnly: computeName = "CPU only (.cpuOnly)"
        @unknown default: computeName = "unknown"
        }
        print("Model variant: \(variantName)")
        print("Compute units: \(computeName)")

        do {
            print("Loading model...")
            let config = RMBG2Configuration(modelVariant: modelVariant, computeUnits: computeUnits)
            let rmbg = try await RMBG2(configuration: config) { progress, status in
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

    static func handleCache(args: [String]) async {
        guard args.count >= 1 else {
            print("Cache commands:")
            print("  cache info   - Show cache location and status")
            print("  cache clear  - Clear cached model files")
            exit(0)
        }

        let subcommand = args[0]

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
        Usage: rmbg2-cli [options] <input_image> [output_image]
               rmbg2-cli [options] process <input_image> [output_image]
               rmbg2-cli cache <info|clear>

        Options:
          --model <variant>   Model to use: int8 (default, 233MB) or full (461MB)
          --compute <units>   Compute units: all/ane (default), cpuAndGPU/gpu, cpuOnly/cpu

        Commands:
          process   Remove background from an image
          cache     Manage cached model files
          help      Show this help message

        Examples:
          rmbg2-cli photo.jpg                           # INT8 model, ANE (default)
          rmbg2-cli --model full photo.jpg              # FP32 full precision
          rmbg2-cli --compute cpuAndGPU photo.jpg       # Force GPU (for debugging)
          rmbg2-cli --model int8 photo.jpg out.png      # Explicit INT8
          rmbg2-cli cache info                          # Show cache location
          rmbg2-cli cache clear                         # Clear cached model

        The model is automatically downloaded on first use.
        Cache location: ~/Library/Caches/models/VincentGOURBIN/RMBG-2-CoreML/

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
