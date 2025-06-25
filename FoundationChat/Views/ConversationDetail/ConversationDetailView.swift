import FoundationModels
import SwiftData
import SwiftUI

struct ConversationDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(ChatEngine.self) private var chatEngine

  @State var newMessage: String = ""
  @State var conversation: Conversation

  var body: some View {
    ScrollView {
      LazyVStack {
        ForEach(conversation.messages) { message in
          VStack(alignment: .leading) {
            Text(message.role.rawValue)
              .font(.headline)
              .fontWeight(.bold)
            Text(message.content)
              .font(.subheadline)
          }
        }
      }
    }
    .navigationTitle("Messages")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarRole(.editor)
    .toolbar {
      ToolbarItemGroup(placement: .bottomBar) {
        TextField("Message", text: $newMessage)
          .textFieldStyle(.plain)
          .padding()
          .contentShape(Rectangle())
        Button(action: {
          conversation.messages.append(
            Message(
              content: newMessage, role: .user,
              timestamp: Date()))
          try? modelContext.save()
          newMessage = ""

          Task {
            if let stream = await chatEngine.respondTo(message: conversation.messages.last!) {
              var newMessage = Message(
                content: "", role: .assistant,
                timestamp: Date())
              conversation.messages.append(newMessage)
              for try await part in stream {
                newMessage.content += part.content ?? ""
              }
              try? modelContext.save()
            }
          }
        }) {
          Label("Send", systemImage: "paperplane")
        }
      }
    }
  }
}
