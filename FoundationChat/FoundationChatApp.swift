import SwiftData
import SwiftUI

@main
struct FoundationChatApp: App {
  var body: some Scene {
    WindowGroup {
      ConversationsListView()
        .modelContainer(for: [Conversation.self, Message.self])
    }
  }
}
