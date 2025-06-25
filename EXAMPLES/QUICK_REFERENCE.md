# Foundation Models Quick Reference

## Essential Imports
```swift
import FoundationModels
```

## Check Availability
```swift
guard SystemLanguageModel.default.isAvailable else { return }
```

## Basic Text Generation
```swift
let session = LanguageModelSession()
let response = try await session.respond(to: "Your prompt here")
print(response.content)
```

## Session with Instructions
```swift
let session = LanguageModelSession(instructions: """
    You are a helpful assistant.
    Be concise and accurate.
    """)
```

## Structured Output
```swift
@Generable
struct MyOutput {
    let title: String
    let items: [String]
}

let response = try await session.respond(
    to: "Generate something",
    generating: MyOutput.self
)
let output: MyOutput = response.content
```

## Streaming
```swift
for try await chunk in session.streamResponse(to: prompt) {
    // Update UI with chunk
    currentText = chunk
}
```

## With @Guide
```swift
@Generable
struct Guided {
    @Guide(description: "A catchy title")
    let title: String
    
    @Guide(.count(5))
    let items: [String]
    
    @Guide(.range(1...10))
    let rating: Int
}
```

## Tool Creation
```swift
struct MyTool: Tool {
    let name = "myTool"
    let description = "What this tool does"
    
    @Generable
    struct Arguments {
        let query: String
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Tool logic here
        return ToolOutput("Result")
    }
}

// Use with session
let session = LanguageModelSession(tools: [MyTool()])
```

## Error Handling
```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Handle safety violation
} catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    // Handle context overflow
}
```

## Performance Tips
```swift
// Prewarm
session.prewarm()

// Skip schema after first request
includeSchemaInPrompt: false

// Temperature
GenerationOptions(temperature: 0.3)  // Accurate
GenerationOptions(temperature: 2.0)  // Creative
```

## Availability States
```swift
switch model.availability {
case .available:
    // Ready to use
case .unavailable(.deviceNotEligible):
    // Device doesn't support
case .unavailable(.appleIntelligenceNotEnabled):
    // User needs to enable
case .unavailable(.modelNotReady):
    // Still downloading
case .unavailable(_):
    // Other reason
}
```