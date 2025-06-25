# Performance Optimization and Safety

## Prewarming for Better Performance

```swift
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
@Observable
class OptimizedChatModel {
    private var session: LanguageModelSession?
    var isModelReady = false
    
    init() {
        setupSession()
    }
    
    private func setupSession() {
        guard SystemLanguageModel.default.isAvailable else { return }
        
        session = LanguageModelSession(instructions: """
            You are a helpful assistant.
            Provide clear, concise responses.
            """)
        
        // Prewarm when the model is created
        session?.prewarm()
    }
    
    func prewarmOnIntent() {
        // Call this when user shows intent to use the model
        // For example: when they focus on input field
        session?.prewarm()
        isModelReady = true
    }
    
    func respond(to prompt: String) async throws -> String {
        guard let session = session else {
            throw AppError.modelNotAvailable
        }
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

// Usage in SwiftUI
struct OptimizedChatView: View {
    @State private var model = OptimizedChatModel()
    @State private var input = ""
    
    var body: some View {
        VStack {
            TextField("Type your message...", text: $input)
                .onEditingChanged { isEditing in
                    if isEditing {
                        // Prewarm when user starts typing
                        model.prewarmOnIntent()
                    }
                }
        }
    }
}
```

## Schema Optimization

```swift
@available(iOS 26.0, *)
class SchemaOptimizedGenerator {
    private let session: LanguageModelSession
    private var isFirstRequest = true
    
    @Generable
    struct Analysis {
        let sentiment: Sentiment
        let keyTopics: [String]
        let summary: String
        
        @Generable
        enum Sentiment {
            case positive
            case neutral
            case negative
        }
    }
    
    init() {
        // Include full example in instructions
        session = LanguageModelSession(instructions: """
            Analyze text and provide structured output.
            
            Example output:
            {
                "sentiment": "positive",
                "keyTopics": ["technology", "innovation", "future"],
                "summary": "An optimistic view of technological advancement"
            }
            """)
    }
    
    func analyze(text: String) async throws -> Analysis {
        let options = GenerationOptions(temperature: 0.3) // Low temp for consistency
        
        // Skip schema inclusion after first request
        let response = try await session.respond(
            to: "Analyze this text: \(text)",
            generating: Analysis.self,
            includeSchemaInPrompt: isFirstRequest,
            options: options
        )
        
        isFirstRequest = false
        return response.content
    }
}
```

## Safety Implementation

```swift
import FoundationModels

@available(iOS 26.0, *)
class SafeContentGenerator {
    private let session: LanguageModelSession
    private let denyList = Set([
        "harmful_term1",
        "harmful_term2",
        // Add more terms as needed
    ])
    
    init() {
        session = LanguageModelSession(instructions: """
            ALWAYS generate family-friendly, respectful content.
            If asked to create anything inappropriate, respond with:
            "I can help you with positive, constructive content instead."
            
            Focus on educational, creative, and helpful responses.
            NEVER include harmful, offensive, or inappropriate content.
            """)
    }
    
    func generateSafe(prompt: String) async -> Result<String, SafetyError> {
        // Check input against deny list
        if containsDeniedTerms(prompt) {
            return .failure(.deniedInput("Input contains restricted terms"))
        }
        
        do {
            let response = try await session.respond(to: prompt)
            
            // Check output against deny list
            if containsDeniedTerms(response.content) {
                return .failure(.deniedOutput("Generated content flagged"))
            }
            
            return .success(response.content)
            
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return .failure(.guardrailViolation("Content blocked by safety system"))
        } catch {
            return .failure(.generationError(error.localizedDescription))
        }
    }
    
    private func containsDeniedTerms(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return denyList.contains { term in
            lowercased.contains(term)
        }
    }
    
    enum SafetyError: LocalizedError {
        case deniedInput(String)
        case deniedOutput(String)
        case guardrailViolation(String)
        case generationError(String)
        
        var errorDescription: String? {
            switch self {
            case .deniedInput(let message),
                 .deniedOutput(let message),
                 .guardrailViolation(let message),
                 .generationError(let message):
                return message
            }
        }
    }
}
```

## Bounded Input/Output

```swift
@available(iOS 26.0, *)
struct BoundedAssistant {
    @Generable
    enum TopicCategory {
        case cooking
        case fitness
        case technology
        case travel
        case education
    }
    
    @Generable
    enum ResponseType {
        case tip
        case explanation
        case recommendation
        case warning
    }
    
    @Generable
    struct BoundedResponse {
        let category: TopicCategory
        let type: ResponseType
        @Guide(.count(1...3))
        let points: [String]
        @Guide(description: "One sentence summary")
        let summary: String
    }
    
    private let session = LanguageModelSession(instructions: """
        You are a helpful assistant that provides structured advice.
        Only respond about the allowed topic categories.
        Keep responses concise and actionable.
        """)
    
    func respond(to userInput: String) async throws -> BoundedResponse {
        // Even with open input, output is bounded to safe structure
        let response = try await session.respond(
            to: userInput,
            generating: BoundedResponse.self,
            options: GenerationOptions(temperature: 0.7)
        )
        return response.content
    }
}
```

## Performance Monitoring

```swift
import FoundationModels
import os.log

@available(iOS 26.0, *)
class MonitoredSession {
    private let session: LanguageModelSession
    private let logger = Logger(subsystem: "com.app.ai", category: "Performance")
    
    struct PerformanceMetrics {
        let promptLength: Int
        let responseTime: TimeInterval
        let responseLength: Int
        let temperature: Double
        let timestamp: Date
    }
    
    private var metrics: [PerformanceMetrics] = []
    
    init() {
        session = LanguageModelSession()
    }
    
    func respondWithMetrics(
        to prompt: String,
        temperature: Double = 1.0
    ) async throws -> (content: String, metrics: PerformanceMetrics) {
        let startTime = Date()
        
        logger.info("Starting generation - prompt length: \(prompt.count)")
        
        let options = GenerationOptions(temperature: temperature)
        let response = try await session.respond(to: prompt, options: options)
        
        let responseTime = Date().timeIntervalSince(startTime)
        
        let metric = PerformanceMetrics(
            promptLength: prompt.count,
            responseTime: responseTime,
            responseLength: response.content.count,
            temperature: temperature,
            timestamp: startTime
        )
        
        metrics.append(metric)
        
        logger.info("""
            Generation complete:
            - Response time: \(responseTime)s
            - Response length: \(response.content.count)
            - Tokens/sec: \(Double(response.content.count) / responseTime)
            """)
        
        return (response.content, metric)
    }
    
    func averageResponseTime() -> TimeInterval? {
        guard !metrics.isEmpty else { return nil }
        let total = metrics.reduce(0) { $0 + $1.responseTime }
        return total / Double(metrics.count)
    }
    
    func performanceSummary() -> String {
        guard !metrics.isEmpty else { return "No metrics available" }
        
        let avgTime = averageResponseTime() ?? 0
        let avgPromptLength = metrics.reduce(0) { $0 + $1.promptLength } / metrics.count
        let avgResponseLength = metrics.reduce(0) { $0 + $1.responseLength } / metrics.count
        
        return """
            Performance Summary:
            - Total requests: \(metrics.count)
            - Average response time: \(String(format: "%.2f", avgTime))s
            - Average prompt length: \(avgPromptLength) characters
            - Average response length: \(avgResponseLength) characters
            """
    }
}
```

## Context Window Management

```swift
@available(iOS 26.0, *)
class ContextManagedChat {
    private var session: LanguageModelSession
    private let maxRetries = 3
    
    init() {
        session = createSession()
    }
    
    private func createSession() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You are a helpful conversational assistant.
            Keep responses concise to manage context efficiently.
            """)
    }
    
    func chat(message: String) async throws -> String {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let response = try await session.respond(to: message)
                return response.content
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                // Handle context overflow
                if attempt == 0 {
                    // First attempt: Try to preserve some history
                    session = createSessionWithCondensedHistory()
                } else {
                    // Subsequent attempts: Start fresh
                    session = createSession()
                }
                lastError = ContextError.contextOverflow
            } catch {
                throw error
            }
        }
        
        throw lastError ?? ContextError.unknown
    }
    
    private func createSessionWithCondensedHistory() -> LanguageModelSession {
        let oldTranscript = session.transcript
        let entries = oldTranscript.entries
        
        // Keep first and last few entries
        var condensedEntries: [Transcript.Entry] = []
        
        if let first = entries.first {
            condensedEntries.append(first)
        }
        
        if entries.count > 4 {
            // Add summary entry
            let summary = Transcript.Entry(
                role: .system,
                content: "Previous conversation covered multiple topics."
            )
            condensedEntries.append(summary)
        }
        
        // Keep last 2 entries
        if entries.count >= 2 {
            condensedEntries.append(contentsOf: entries.suffix(2))
        }
        
        let condensedTranscript = Transcript(entries: condensedEntries)
        return LanguageModelSession(transcript: condensedTranscript)
    }
    
    enum ContextError: LocalizedError {
        case contextOverflow
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .contextOverflow:
                return "Conversation too long, starting fresh context"
            case .unknown:
                return "An unknown error occurred"
            }
        }
    }
}
```