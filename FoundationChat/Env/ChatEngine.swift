import FoundationModels
import SwiftUI

@Observable
class ChatEngine {
  private let model = SystemLanguageModel.default
  private let session: LanguageModelSession
  private let conversation: Conversation

  var isAvailable: Bool {
    switch model.availability {
    case .available:
      return true
    default:
      return false
    }
  }

  init(conversation: Conversation) {
    self.conversation = conversation
    session = LanguageModelSession {
      """
      You're an helpful chatbot. The user will send you messages, and you'll respond to them. 
      Be short, it's a chat application.
      You can also summarize the conversation when asked to.
      Each messages will have a role, either user or assistant or system for initial conversation configuration.
      """
    }
  }

  func prewarm() {
    session.prewarm()
  }

  func respondTo(message: Message) async -> LanguageModelSession.ResponseStream<MessageGenerable>? {
    session.streamResponse(generating: MessageGenerable.self) {
      """
      Here is the conversation history:
      \(conversation.messages.map { "Role: \($0.role.rawValue)\nContent: \($0.content)" }.joined(separator: "\n\n"))
      You should respond with the assistant role to the user last message.
      """
    }
  }

  func summarize() async -> LanguageModelSession.ResponseStream<String>? {
    session.streamResponse {
      """
      Here is the conversation history:
      \(conversation.messages.map { "Role: \($0.role.rawValue)\nContent: \($0.content)" }.joined(separator: "\n\n"))
      Summarize the conversation in one sentence.
      """
    }
  }
}
