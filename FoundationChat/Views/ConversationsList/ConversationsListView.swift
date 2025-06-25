import SwiftData
import SwiftUI

struct ConversationsListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var conversations: [Conversation]

  var body: some View {
    NavigationStack {
      List(conversations.sorted(by: { $0.lastMessageTimestamp > $1.lastMessageTimestamp })) { conversation in
        NavigationLink(value: conversation) {
          ConversationRowView(conversation: conversation)
            .swipeActions {
              Button(role: .destructive) {
                modelContext.delete(conversation)
                try? modelContext.save()
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
        }
      }
      .onAppear {
        if conversations.isEmpty {
          for conversation in placeholders {
            modelContext.insert(conversation)
          }
          try? modelContext.save()
        }
      }
      .listStyle(.plain)
      .navigationDestination(for: Conversation.self) { conversation in
        ConversationDetailView(conversation: conversation)
          .environment(ChatEngine(conversation: conversation))
      }
      .navigationTitle("Conversations")
    }
  }
}
