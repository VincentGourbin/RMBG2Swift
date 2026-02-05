# RMBG2Swift

> **License Notice**: This package uses the RMBG-2.0 model by [BRIA AI](https://bria.ai) under **CC BY-NC 4.0**.
> Free for non-commercial use. Commercial use requires a license from [BRIA AI](https://bria.ai/contact-us).

Swift Package for high-quality background removal using BRIA AI's RMBG-2.0 model, optimized for Apple Neural Engine.

## Features

- Simple, high-level API for background removal
- Automatic model download from HuggingFace
- **Two model variants**: INT8 quantized (233 MB) or FP32 full precision (461 MB)
- Optimized for Apple Neural Engine (ANE) with automatic fallback to GPU
- Support for macOS 13+ and iOS 16+
- Progress tracking during model download
- Batch processing support

## Installation

### Swift Package Manager

Add RMBG2Swift to your project using Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/VincentGourbin/RMBG2Swift`
3. Select version and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VincentGourbin/RMBG2Swift", from: "1.0.0")
]
```

## Quick Start

```swift
import RMBG2Swift

// Create instance (downloads model on first use)
let rmbg = try await RMBG2()

// Remove background
let result = try await rmbg.removeBackground(from: image)

// Use the result
let outputImage = result.image  // Image with transparent background
let mask = result.mask          // Grayscale segmentation mask
let time = result.inferenceTime // Inference duration
```

### With Progress Tracking

```swift
let rmbg = try await RMBG2 { progress, status in
    print("\(status): \(Int(progress * 100))%")
}
```

## Advanced Usage

### Model Variants

Two model variants are available:

| Variant | Size | Description |
|---------|------|-------------|
| `.quantized` (default) | 233 MB | INT8 quantized, ANE optimized, recommended |
| `.full` | 461 MB | FP32 full precision |

```swift
// INT8 quantized model (default, recommended)
let rmbg = try await RMBG2(configuration: .int8)

// Full precision FP32 model
let rmbg = try await RMBG2(configuration: .fullPrecision)
```

### Static Configurations

```swift
// Model variants
RMBG2Configuration.default       // INT8 + ANE (recommended)
RMBG2Configuration.int8          // INT8 + ANE (explicit)
RMBG2Configuration.fullPrecision // FP32 + ANE

// Compute unit variants
RMBG2Configuration.cpuAndGPU     // INT8 + CPU/GPU (no ANE)
RMBG2Configuration.cpuOnly       // INT8 + CPU only
```

### Custom Configuration

```swift
import RMBG2Swift

// Full control
let config = RMBG2Configuration(
    modelVariant: .quantized,     // .quantized (INT8) or .full (FP32)
    computeUnits: .all,           // .cpuOnly, .cpuAndGPU, .all (ANE)
    modelURL: customModelURL,     // Optional: use local model
    cacheDirectory: customDir     // Optional: custom cache location
)

let rmbg = try await RMBG2(configuration: config)
```

> **Note**: If ANE loading fails, the library automatically falls back to CPU+GPU.

### Generate Mask Only

```swift
let mask = try await rmbg.generateMask(from: image)
```

### Apply Custom Mask

```swift
let outputImage = rmbg.applyMask(customMask, to: image)
```

### Batch Processing

```swift
let results = try await rmbg.removeBackground(from: [image1, image2, image3])
```

### Platform-Specific Convenience

```swift
// macOS
let result = try await rmbg.removeBackground(from: nsImage)

// iOS
let result = try await rmbg.removeBackground(from: uiImage)
```

## CLI Tool

The package includes a command-line tool:

```bash
# Build
swift build -c release

# Remove background from image
.build/release/rmbg2-cli photo.jpg output.png

# Cache management
.build/release/rmbg2-cli cache info
.build/release/rmbg2-cli cache clear
```

## Model Information

| Property | Value |
|----------|-------|
| Architecture | BiRefNet (RMBG-2.0) |
| Input Size | 1024 x 1024 |
| Format | CoreML ML Program |
| Compute Units | CPU, GPU, ANE |
| Minimum OS | macOS 13+ / iOS 16+ |

### Model Variants

| Variant | File | Size | Quantization |
|---------|------|------|--------------|
| INT8 (default) | `RMBG-2-native-int8.mlpackage` | 233 MB | INT8 symmetric |
| Full Precision | `RMBG-2-native.mlpackage` | 461 MB | FP32 |

### Performance

| Device | Compute Units | Inference Time |
|--------|--------------|---------------|
| M1 Pro | .all (ANE) | ~5s |
| M1 Pro | .cpuAndGPU | ~3s |

> **Note**: Performance varies by device and model variant.

## Cache Location

The model is automatically downloaded and cached at:
- **macOS/iOS**: `~/Library/Caches/models/VincentGOURBIN/RMBG-2-CoreML/`

## API Reference

### RMBG2

```swift
// Initialization
init(progress: DownloadProgressHandler?) async throws
init(configuration: RMBG2Configuration, progress: DownloadProgressHandler?) async throws

// Main API
func removeBackground(from image: CGImage) async throws -> RMBG2Result
func generateMask(from image: CGImage) async throws -> CGImage
func applyMask(_ mask: CGImage, to image: CGImage) -> CGImage?

// Batch processing
func removeBackground(from images: [CGImage]) async throws -> [RMBG2Result]
```

### RMBG2Result

```swift
struct RMBG2Result {
    let image: CGImage           // Image with transparent background
    let mask: CGImage            // Grayscale segmentation mask
    let inferenceTime: TimeInterval
}
```

### ModelVariant

```swift
enum ModelVariant {
    case quantized  // INT8, 233 MB (default, recommended)
    case full       // FP32, 461 MB
}
```

### RMBG2Configuration

```swift
struct RMBG2Configuration {
    let modelVariant: ModelVariant     // .quantized or .full
    let computeUnits: MLComputeUnits   // .all, .cpuAndGPU, .cpuOnly
    let modelURL: URL?                 // Custom model path
    let cacheDirectory: URL?           // Custom cache directory

    // Static configurations
    static let `default`: RMBG2Configuration      // INT8 + ANE
    static let int8: RMBG2Configuration           // INT8 + ANE
    static let fullPrecision: RMBG2Configuration  // FP32 + ANE
    static let cpuAndGPU: RMBG2Configuration      // INT8 + CPU/GPU
    static let cpuOnly: RMBG2Configuration        // INT8 + CPU
}
```

## License & Attribution

This package uses the **RMBG-2.0** model by **BRIA AI**.

- **License**: [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
- **Free for**: Research, personal projects, education
- **Commercial use**: Requires separate license from [BRIA AI](https://bria.ai/contact-us)

### Links

- [Original RMBG-2.0 Model](https://huggingface.co/briaai/RMBG-2.0)
- [CoreML Model on HuggingFace](https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML)
- [BRIA AI](https://bria.ai)

## Project Structure

```
RMBG2Swift/
├── Package.swift
├── Sources/RMBG2Swift/
│   ├── RMBG2.swift              # Main public API
│   ├── RMBG2Configuration.swift # Configuration options
│   ├── RMBG2Error.swift         # Error types
│   ├── ModelDownloader.swift    # HuggingFace download
│   ├── ImageProcessing.swift    # CGImage ↔ MLMultiArray
│   └── Internal/
│       └── Constants.swift      # Model URLs, sizes, etc.
├── Tests/RMBG2SwiftTests/
│   └── RMBG2Tests.swift
└── Examples/CLI/
    └── main.swift               # CLI tool
```

## Conversion Scripts

The native conversion scripts are preserved for reproducibility:

- `convert_native.py` - Main conversion script
- `native_deform_conv.py` - Native deformable convolution implementation

To reconvert the model:

```bash
# Create environment
python3 -m venv venv
source venv/bin/activate
pip install torch torchvision transformers coremltools pillow numpy

# Run conversion
python convert_native.py
```

## Contributing

Contributions are welcome! Please ensure any changes maintain compatibility with both macOS and iOS platforms.

## Acknowledgments

- [BRIA AI](https://bria.ai) for the RMBG-2.0 model
- [BiRefNet](https://github.com/ZhengPeng7/BiRefNet) architecture
