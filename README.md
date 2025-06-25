# FoundationChat

A SwiftUI chat application built with Apple's Foundation Models framework, showcasing on-device AI capabilities.

## Requirements

- **iOS 26.0+** / iPadOS 26.0+ / macOS 26.0+ / visionOS 26.0+
- **Xcode 26.0+** (with iOS 26 SDK)
- Device with Apple Intelligence support
- Apple Intelligence must be enabled in Settings

## Features

- ✅ On-device AI chat with no internet required
- ✅ Real-time streaming responses
- ✅ Automatic availability checking
- ✅ Context management
- ✅ Safety guardrails
- ✅ Performance optimizations
- ✅ Clean SwiftUI interface

## Getting Started

1. Open `FoundationChat.xcodeproj` in Xcode
2. Ensure your development device has Apple Intelligence enabled
3. Build and run on a supported device (not simulator for accurate performance)

## Key Concepts

### Availability Checking
Always check if the model is available before use:
```swift
guard SystemLanguageModel.default.isAvailable else { 
    // Show fallback UI
    return 
}
```

### Basic Usage
```swift
let session = LanguageModelSession()
let response = try await session.respond(to: "Hello!")
print(response.content)
```

### Streaming Responses
```swift
for try await chunk in session.streamResponse(to: prompt) {
    // Update UI with partial content
}
```

## Documentation

- [Examples](EXAMPLES/) - Detailed implementation examples

## Contributing

This is an example project demonstrating Foundation Models usage. Feel free to fork and experiment!

## License

MIT License - See LICENSE file for details