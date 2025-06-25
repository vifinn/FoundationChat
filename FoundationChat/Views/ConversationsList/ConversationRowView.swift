import SwiftUI

struct ConversationRowView: View {
  let conversation: Conversation

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading) {
        Text(conversation.messages.last?.role.rawValue ?? "Unknown")
          .font(.headline)
          .fontWeight(.bold)
        Text(conversation.summary ?? "No summary")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(
        Date(
          timeIntervalSince1970: conversation.messages.last?.timestamp.timeIntervalSince1970 ?? 0
        ).formatted(
          date: .omitted, time: .shortened)
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}
