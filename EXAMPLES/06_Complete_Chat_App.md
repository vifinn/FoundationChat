# Complete Chat App Example

## Chat Message Model

```swift
import Foundation
import FoundationModels

@available(iOS 26.0, *)
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    let error: Error?
    
    enum Role {
        case user
        case assistant
        case system
        
        var displayName: String {
            switch self {
            case .user: return "You"
            case .assistant: return "Assistant"
            case .system: return "System"
            }
        }
    }
    
    init(role: Role, content: String, error: Error? = nil) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.error = error
    }
}
```

## Chat Manager

```swift
import Foundation
import FoundationModels
import Observation

@available(iOS 26.0, *)
@Observable
class ChatManager {
    // MARK: - Properties
    
    var messages: [ChatMessage] = []
    var isGenerating = false
    var currentStreamingContent = ""
    var modelAvailability: SystemLanguageModel.Availability
    
    private var session: LanguageModelSession?
    private let model = SystemLanguageModel.default
    
    // MARK: - Initialization
    
    init() {
        self.modelAvailability = model.availability
        setupSession()
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Check availability
        guard case .available = modelAvailability else {
            let errorMessage = getAvailabilityErrorMessage()
            messages.append(ChatMessage(role: .system, content: errorMessage))
            return
        }
        
        // Generate response
        isGenerating = true
        currentStreamingContent = ""
        
        do {
            // Prewarm if this is the first message
            if messages.count == 1 {
                session?.prewarm()
            }
            
            let response = await streamResponse(to: text)
            messages.append(ChatMessage(role: .assistant, content: response))
        } catch {
            handleError(error)
        }
        
        isGenerating = false
        currentStreamingContent = ""
    }
    
    func clearChat() {
        messages.removeAll()
        setupSession()
    }
    
    func refreshAvailability() {
        modelAvailability = model.availability
        if case .available = modelAvailability {
            setupSession()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSession() {
        guard case .available = modelAvailability else { return }
        
        session = LanguageModelSession(instructions: """
            You are a helpful AI assistant integrated into a chat application.
            Provide clear, concise, and friendly responses.
            If asked about your capabilities, mention that you:
            - Run entirely on-device for privacy
            - Can help with various tasks and questions
            - Have built-in safety features
            
            Keep responses conversational but informative.
            """)
    }
    
    private func streamResponse(to prompt: String) async -> String {
        guard let session = session else {
            throw ChatError.sessionNotAvailable
        }
        
        do {
            var fullResponse = ""
            
            for try await chunk in session.streamResponse(to: prompt) {
                currentStreamingContent = chunk
                fullResponse = chunk
            }
            
            return fullResponse
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            throw ChatError.contentBlocked
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Try to recover by creating new session
            setupSession()
            throw ChatError.contextOverflow
        } catch {
            throw error
        }
    }
    
    private func handleError(_ error: Error) {
        let errorMessage: String
        
        if let chatError = error as? ChatError {
            errorMessage = chatError.userFriendlyMessage
        } else {
            errorMessage = "An error occurred: \(error.localizedDescription)"
        }
        
        messages.append(ChatMessage(
            role: .system,
            content: errorMessage,
            error: error
        ))
    }
    
    private func getAvailabilityErrorMessage() -> String {
        switch modelAvailability {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence features."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings to use this feature."
        case .unavailable(.modelNotReady):
            return "The AI model is still downloading. Please try again later."
        case .unavailable(_):
            return "The AI assistant is temporarily unavailable."
        }
    }
}

// MARK: - Error Types

enum ChatError: LocalizedError {
    case sessionNotAvailable
    case contentBlocked
    case contextOverflow
    
    var userFriendlyMessage: String {
        switch self {
        case .sessionNotAvailable:
            return "The chat session is not available. Please try again."
        case .contentBlocked:
            return "The content was blocked by safety filters. Please try a different prompt."
        case .contextOverflow:
            return "The conversation is too long. Starting a new session..."
        }
    }
}
```

## Main Chat View

```swift
import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
struct ChatView: View {
    @State private var chatManager = ChatManager()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatManager.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if chatManager.isGenerating {
                                StreamingMessageBubble(
                                    content: chatManager.currentStreamingContent
                                )
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatManager.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(
                                chatManager.isGenerating ? "streaming" : chatManager.messages.last?.id,
                                anchor: .bottom
                            )
                        }
                    }
                }
                
                Divider()
                
                // Input area
                InputArea(
                    text: $inputText,
                    isGenerating: chatManager.isGenerating,
                    onSend: {
                        Task {
                            await chatManager.sendMessage(inputText)
                            inputText = ""
                        }
                    }
                )
                .focused($isInputFocused)
                .onAppear {
                    // Prewarm when view appears
                    if case .available = chatManager.modelAvailability {
                        chatManager.session?.prewarm()
                    }
                }
            }
            .navigationTitle("AI Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            chatManager.clearChat()
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                        
                        Button {
                            chatManager.refreshAvailability()
                        } label: {
                            Label("Refresh Availability", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    AvailabilityIndicator(availability: chatManager.modelAvailability)
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                if message.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return .orange.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }
}

// MARK: - Streaming Message Bubble

struct StreamingMessageBubble: View {
    let content: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(content.isEmpty ? "Thinking..." : content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    if content.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Spacer(minLength: 60)
        }
    }
}

// MARK: - Input Area

struct InputArea: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(isGenerating)
                .onSubmit {
                    if !text.isEmpty && !isGenerating {
                        onSend()
                    }
                }
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(text.isEmpty || isGenerating)
        }
        .padding()
    }
}

// MARK: - Availability Indicator

struct AvailabilityIndicator: View {
    let availability: SystemLanguageModel.Availability
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            
            if case .unavailable(_) = availability {
                Text("Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var iconName: String {
        switch availability {
        case .available:
            return "circle.fill"
        case .unavailable(.modelNotReady):
            return "arrow.down.circle"
        default:
            return "circle.slash"
        }
    }
    
    private var iconColor: Color {
        switch availability {
        case .available:
            return .green
        case .unavailable(.modelNotReady):
            return .orange
        default:
            return .red
        }
    }
}
```

## App Entry Point

```swift
import SwiftUI

@main
struct FoundationChatApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 26.0, *) {
                ChatView()
            } else {
                UnsupportedVersionView()
            }
        }
    }
}

struct UnsupportedVersionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("iOS 26 Required")
                .font(.title)
                .bold()
            
            Text("This app requires iOS 26 or later to use Apple's Foundation Models.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button("Check for Updates") {
                // Open Settings
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## Advanced Features Extension

```swift
// Add these features to enhance the chat app

@available(iOS 26.0, *)
extension ChatManager {
    // Export chat history
    func exportChatHistory() -> String {
        messages.map { message in
            "[\(message.timestamp.formatted())] \(message.role.displayName): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    // Save/Load functionality
    func saveChatHistory() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(messages)
        
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
        
        try data.write(to: url)
    }
    
    func loadChatHistory() throws {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_history.json")
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        messages = try decoder.decode([ChatMessage].self, from: data)
    }
}

// Make ChatMessage Codable for save/load
extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case role, content, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        error = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension ChatMessage.Role: Codable {}
```