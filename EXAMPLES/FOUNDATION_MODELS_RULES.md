# Foundation Models Framework Rules

## Core Principles

1. **Always Check Availability First**
   - The model may not be available if:
     - Device doesn't support Apple Intelligence
     - Apple Intelligence is not enabled
     - Model is still downloading
     - Device is in low battery mode or too warm
   - Always provide fallback UI/behavior

2. **Session Management**
   - Create new session for single-turn interactions
   - Reuse session for multi-turn conversations
   - Sessions maintain context between requests
   - Only one request per session at a time

3. **Imports Required**
   ```swift
   import FoundationModels
   ```

## Availability Checking

```swift
private var model = SystemLanguageModel.default

switch model.availability {
case .available:
    // Model is ready to use
case .unavailable(.deviceNotEligible):
    // Device doesn't support Apple Intelligence
case .unavailable(.appleIntelligenceNotEnabled):
    // User needs to enable Apple Intelligence
case .unavailable(.modelNotReady):
    // Model is downloading or system busy
case .unavailable(let other):
    // Unknown reason
}
```

## Session Creation

### Basic Session
```swift
let session = LanguageModelSession()
```

### Session with Instructions
```swift
let session = LanguageModelSession(instructions: """
    You are a helpful assistant.
    Respond concisely and accurately.
    """)
```

### Session with Tools
```swift
let session = LanguageModelSession(
    tools: [MyCustomTool()],
    instructions: "You can use tools to help answer questions."
)
```

## Prompting Rules

1. **Keep prompts focused and specific**
2. **Use conversational language**
3. **Specify output length when needed** (e.g., "in three sentences")
4. **Shorter prompts = faster responses**
5. **Instructions override prompts**

## Structured Output (@Generable)

1. **All properties must be Generable types**
2. **Common types (String, Int, Bool, etc.) are Generable by default**
3. **Nested types must also be @Generable**
4. **Enums provide constrained choices**

## @Guide Annotations

- `@Guide(description: "...")` - Natural language hints
- `@Guide(.count(n))` - Exact number of array elements
- `@Guide(.range(min...max))` - Numeric ranges
- `@Guide(Regex {...})` - Pattern matching
- Multiple guides can be combined

## Streaming vs. Non-Streaming

- **Use streaming for**:
  - Responses longer than a sentence
  - Better perceived performance
  - Real-time UI updates
  
- **Use non-streaming for**:
  - Short responses
  - Structured data generation
  - When you need complete response before proceeding

## Performance Optimizations

1. **Prewarm sessions** when user shows intent
   ```swift
   session.prewarm()
   ```

2. **Disable schema inclusion** for:
   - Subsequent requests in same session
   - When instructions contain full examples
   ```swift
   options: .init(includeSchemaInPrompt: false)
   ```

3. **Temperature tuning**:
   - Low (0.3): Accurate, predictable (corrections, facts)
   - Default (1.0): Balanced
   - High (2.0): Creative, varied (stories, suggestions)

## Error Handling

Always handle these errors:
- `GenerationError.exceededContextWindowSize`
- `GenerationError.guardrailViolation`
- `GenerationError.unsupportedLanguageOrLocale`
- Tool calling errors

## Safety Rules

1. **Never put user input in instructions** (prompt injection risk)
2. **Always handle guardrail violations gracefully**
3. **Consider adding deny lists for sensitive terms**
4. **Test with adversarial inputs**
5. **Provide clear error messages to users**

## Tool Development

1. Tools must conform to `Tool` protocol
2. Provide clear `name` and `description`
3. Define `Arguments` as @Generable struct
4. Return `ToolOutput` from `call()` method
5. Tools can maintain state if needed

## Platform Requirements

- iOS 26.0+
- iPadOS 26.0+
- macOS 26.0+
- visionOS 26.0+
- Device must support Apple Intelligence

## Testing Guidelines

1. **Always test on real devices** (simulator performance differs)
2. **Use Foundation Models Instrument in Xcode**
3. **Test all availability states**
4. **Run adversarial safety tests**
5. **Monitor token counts and response times**