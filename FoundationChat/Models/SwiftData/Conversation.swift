import Foundation
import SwiftData

@Model
class Conversation {
  @Relationship(deleteRule: .cascade)
  var messages: [Message]
  var summary: String?

  var lastMessageTimestamp: Date {
    messages.last?.timestamp ?? Date()
  }

  var sortedMessages: [Message] {
    messages.sorted { $0.timestamp < $1.timestamp }
  }

  init(messages: [Message], summary: String?) {
    self.messages = messages
    self.summary = summary
  }
}
