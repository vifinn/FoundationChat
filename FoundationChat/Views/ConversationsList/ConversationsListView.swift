import SwiftData
import SwiftUI

struct ConversationsListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var conversations: [Conversation]

  @State private var path: [Conversation] = []

  var body: some View {
    NavigationStack(path: $path) {
      List {
        ForEach(conversations.sorted(by: { $0.lastMessageTimestamp > $1.lastMessageTimestamp })) {
          conversation in
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
        .listSectionSeparator(.hidden, edges: .top)
      }
      .listStyle(.plain)
      .navigationDestination(for: Conversation.self) { conversation in
        ConversationDetailView(conversation: conversation)
          .environment(ChatEngine(conversation: conversation))
      }
      .navigationTitle("Conversations")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            let newConversation = Conversation(messages: [], summary: "New conversation")
            modelContext.insert(newConversation)
            try? modelContext.save()
            path.append(newConversation)
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
  }
}
