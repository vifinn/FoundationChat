import FoundationModels
import SwiftData
import SwiftUI

struct ConversationDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(ChatEngine.self) private var chatEngine

  @State var newMessage: String = ""
  @State var conversation: Conversation
  @State var scrollPosition: ScrollPosition = .init()
  @State var isGenerating: Bool = false
  @FocusState var isInputFocused: Bool

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(conversation.sortedMessages) { message in
          ConversationMessageView(message: message)
            .id(message.id)
        }
      }
      .scrollTargetLayout()
      .padding(.bottom, 50)
    }
    .onAppear {
      chatEngine.prewarm()
      isInputFocused = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation {
          scrollPosition.scrollTo(edge: .bottom)
        }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .scrollPosition($scrollPosition, anchor: .bottom)
    .navigationTitle("Messages")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarRole(.editor)
    .toolbar {
      ConversationDetailInputView(
        newMessage: $newMessage,
        isGenerating: $isGenerating,
        isInputFocused: $isInputFocused,
        onSend: {
          isGenerating = true
          try? await streamNewMessage()
          isGenerating = false
          try? await updateConversationSummary()
        }
      )
    }
  }
}

extension ConversationDetailView {
  private func streamNewMessage() async throws {
    conversation.messages.append(
      Message(
        content: newMessage, role: .user,
        timestamp: Date()))
    try? modelContext.save()
    newMessage = ""
    if let stream = await chatEngine.respondTo() {
      let newMessage = Message(
        content: "...",
        role: .assistant,
        timestamp: Date())
      conversation.messages.append(newMessage)
      for try await part in stream {
        newMessage.content = part.content ?? ""
      }
      try modelContext.save()
    }
  }

  private func updateConversationSummary() async throws {
    if let stream = await chatEngine.summarize() {
      for try await part in stream {
        conversation.summary = part
      }
      try modelContext.save()
    }
  }
}
