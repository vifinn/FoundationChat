import Foundation
import SwiftData

@Model
class Conversation {
  @Relationship(deleteRule: .cascade)
  var messages: [Message]
  var summary: String?

  init(messages: [Message], summary: String?) {
    self.messages = messages
    self.summary = summary
  }
}

let placeholders: [Conversation] = [
  Conversation(
    messages: [
      Message(
        content: "Hello, how are you?", role: .user,
        timestamp: Date()),
      Message(
        content: "I'm fine, thank you!", role: .assistant,
        timestamp: Date()),
    ], summary: "The user asked how the assistant is doing."),
  Conversation(
    messages: [
      Message(
        content: "Hello, how are you?", role: .user,
        timestamp: Date()),
      Message(
        content: "I'm fine, thank you!", role: .assistant,
        timestamp: Date()),
    ], summary: "The user asked how the assistant is doing."),
  Conversation(
    messages: [
      Message(
        content: "Hello, how are you?", role: .user,
        timestamp: Date()),
      Message(
        content: "I'm fine, thank you!", role: .assistant,
        timestamp: Date()),
    ], summary: "The user asked how the assistant is doing."),
]
