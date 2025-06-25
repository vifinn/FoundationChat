import SwiftData
import SwiftUI

struct ConversationsListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var conversations: [Conversation]

  var body: some View {
    NavigationStack {
      List(conversations) { conversation in
        NavigationLink(value: conversation) {
          ConversationRowView(conversation: conversation)
            .listSectionSeparator(.hidden, edges: .top)
            .swipeActions {
              Button(role: .destructive) {
                modelContext.delete(conversation)
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
