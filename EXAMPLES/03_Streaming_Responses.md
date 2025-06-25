# Streaming Responses

## Basic Text Streaming

```swift
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
@Observable
class StreamingChatModel {
    var currentResponse = ""
    var isGenerating = false
    
    func streamResponse(to prompt: String) async {
        isGenerating = true
        currentResponse = ""
        
        let session = LanguageModelSession()
        
        do {
            for try await chunk in session.streamResponse(to: prompt) {
                currentResponse = chunk
            }
        } catch {
            currentResponse = "Error: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
}

// SwiftUI View
struct StreamingChatView: View {
    @State private var model = StreamingChatModel()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                Text(model.currentResponse)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                TextField("Ask something...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task {
                        await model.streamResponse(to: inputText)
                    }
                }
                .disabled(model.isGenerating || inputText.isEmpty)
            }
            .padding()
        }
    }
}
```

## Streaming Structured Output

```swift
@available(iOS 26.0, *)
@Observable
class StreamingStructuredModel {
    var partialRecipe: PartiallyGenerated<Recipe>?
    var isGenerating = false
    
    func streamRecipe(for dish: String) async {
        isGenerating = true
        partialRecipe = nil
        
        let session = LanguageModelSession(instructions: """
            You are a professional chef creating detailed recipes.
            Include all necessary information for home cooks.
            """)
        
        do {
            let stream = session.streamResponse(
                to: "Create a detailed recipe for \(dish)",
                generating: Recipe.self
            )
            
            for try await partial in stream {
                partialRecipe = partial
            }
        } catch {
            print("Error: \(error)")
        }
        
        isGenerating = false
    }
}

// SwiftUI View for Partial Recipe
struct StreamingRecipeView: View {
    let partial: PartiallyGenerated<Recipe>?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let name = partial?.name {
                    Text(name)
                        .font(.title)
                        .bold()
                }
                
                if let prepTime = partial?.prepTime {
                    Label("\(prepTime) minutes", systemImage: "clock")
                }
                
                if let difficulty = partial?.difficulty {
                    Label(difficulty.displayName, systemImage: "chart.bar")
                }
                
                if let ingredients = partial?.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Ingredients")
                            .font(.headline)
                        ForEach(ingredients, id: \.self) { ingredient in
                            Text("• \(ingredient)")
                        }
                    }
                }
                
                if let instructions = partial?.instructions, !instructions.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Instructions")
                            .font(.headline)
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                            Text("\(index + 1). \(instruction)")
                        }
                    }
                }
            }
            .padding()
            .animation(.easeInOut, value: partial)
        }
    }
}
```

## Advanced Streaming with Error Handling

```swift
@available(iOS 26.0, *)
@Observable
class RobustStreamingModel {
    var content = ""
    var error: StreamingError?
    var isStreaming = false
    var tokensGenerated = 0
    
    private var streamTask: Task<Void, Never>?
    
    enum StreamingError: LocalizedError {
        case guardrailViolation
        case contextOverflow
        case networkError
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .guardrailViolation:
                return "Content was flagged by safety systems"
            case .contextOverflow:
                return "Conversation is too long"
            case .networkError:
                return "Network connection error"
            case .cancelled:
                return "Generation was cancelled"
            }
        }
    }
    
    func startStreaming(prompt: String) {
        // Cancel any existing stream
        streamTask?.cancel()
        
        // Reset state
        content = ""
        error = nil
        isStreaming = true
        tokensGenerated = 0
        
        streamTask = Task {
            await stream(prompt: prompt)
        }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
    }
    
    private func stream(prompt: String) async {
        let session = LanguageModelSession()
        
        do {
            for try await chunk in session.streamResponse(to: prompt) {
                // Check for cancellation
                if Task.isCancelled {
                    error = .cancelled
                    break
                }
                
                content = chunk
                tokensGenerated += 1
            }
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            error = .guardrailViolation
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            error = .contextOverflow
        } catch {
            if !Task.isCancelled {
                error = .networkError
            }
        }
        
        isStreaming = false
    }
}
```

## Streaming with Temperature Control

```swift
@available(iOS 26.0, *)
struct TemperatureStreamingExample {
    enum ResponseStyle {
        case factual
        case balanced
        case creative
        
        var temperature: Double {
            switch self {
            case .factual: return 0.3
            case .balanced: return 1.0
            case .creative: return 2.0
            }
        }
        
        var description: String {
            switch self {
            case .factual: return "Precise and accurate"
            case .balanced: return "Natural and conversational"
            case .creative: return "Imaginative and varied"
            }
        }
    }
    
    func streamWithStyle(
        prompt: String,
        style: ResponseStyle
    ) async throws -> AsyncThrowingStream<String, Error> {
        let session = LanguageModelSession()
        let options = GenerationOptions(temperature: style.temperature)
        
        return session.streamResponse(to: prompt, options: options)
    }
}
```

## Streaming with Progress Tracking

```swift
@available(iOS 26.0, *)
@Observable
class ProgressTrackingStream {
    var content = ""
    var estimatedProgress: Double = 0
    var charactersGenerated = 0
    var wordsGenerated = 0
    
    private let expectedLength: Int
    
    init(expectedLength: Int = 500) {
        self.expectedLength = expectedLength
    }
    
    func streamWithProgress(prompt: String) async {
        content = ""
        estimatedProgress = 0
        charactersGenerated = 0
        wordsGenerated = 0
        
        let session = LanguageModelSession()
        
        do {
            for try await chunk in session.streamResponse(to: prompt) {
                content = chunk
                charactersGenerated = chunk.count
                wordsGenerated = chunk.split(separator: " ").count
                
                // Estimate progress based on character count
                estimatedProgress = min(Double(charactersGenerated) / Double(expectedLength), 0.95)
            }
            
            estimatedProgress = 1.0
        } catch {
            print("Streaming error: \(error)")
        }
    }
}
```