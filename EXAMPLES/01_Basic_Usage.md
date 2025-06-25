# Basic Foundation Models Usage Examples

## Simple Text Generation

```swift
import FoundationModels

@available(iOS 26.0, *)
struct BasicExample {
    func generateText() async throws -> String {
        // Check availability first
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelNotAvailable
        }
        
        // Create session
        let session = LanguageModelSession()
        
        // Make request
        let response = try await session.respond(to: "Write a haiku about coding")
        return response.content
    }
}
```

## Session with Instructions

```swift
@available(iOS 26.0, *)
struct AssistantExample {
    private let session = LanguageModelSession(instructions: """
        You are a helpful coding assistant.
        Provide clear, concise answers.
        Use Swift for code examples.
        """)
    
    func askQuestion(_ question: String) async throws -> String {
        let response = try await session.respond(to: question)
        return response.content
    }
}
```

## Handling Availability States

```swift
@available(iOS 26.0, *)
struct AvailabilityExample: View {
    private var model = SystemLanguageModel.default
    
    var body: some View {
        VStack {
            switch model.availability {
            case .available:
                ChatView()
                
            case .unavailable(.deviceNotEligible):
                Text("This device doesn't support Apple Intelligence")
                    .foregroundColor(.secondary)
                
            case .unavailable(.appleIntelligenceNotEnabled):
                VStack {
                    Text("Apple Intelligence is not enabled")
                    Button("Open Settings") {
                        // Open settings URL
                    }
                }
                
            case .unavailable(.modelNotReady):
                VStack {
                    ProgressView()
                    Text("Model is downloading...")
                }
                
            case .unavailable(_):
                Text("Model temporarily unavailable")
            }
        }
    }
}
```

## Error Handling

```swift
@available(iOS 26.0, *)
struct ErrorHandlingExample {
    func safeGenerate(prompt: String) async -> Result<String, GenerationError> {
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return .success(response.content)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return .failure(.safety("Content flagged by safety guardrails"))
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            return .failure(.contextOverflow("Conversation too long"))
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
}

enum GenerationError: Error {
    case safety(String)
    case contextOverflow(String)
    case unknown(String)
}
```

## Multi-turn Conversation

```swift
@available(iOS 26.0, *)
@Observable
class ConversationManager {
    private var session: LanguageModelSession?
    var messages: [Message] = []
    
    init() {
        self.session = LanguageModelSession(instructions: """
            You are a friendly conversational partner.
            Keep responses brief and engaging.
            """)
    }
    
    func sendMessage(_ text: String) async throws {
        // Add user message
        messages.append(Message(role: .user, content: text))
        
        // Get response
        guard let session = session else { return }
        let response = try await session.respond(to: text)
        
        // Add assistant message
        messages.append(Message(role: .assistant, content: response.content))
    }
    
    func resetConversation() {
        session = LanguageModelSession(instructions: """
            You are a friendly conversational partner.
            Keep responses brief and engaging.
            """)
        messages.removeAll()
    }
}

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role {
        case user
        case assistant
    }
}
```