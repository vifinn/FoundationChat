import Foundation
import SwiftData

@Model
final class Message {
  var content: String
  var role: Role
  var timestamp: Date

  init(content: String, role: Role, timestamp: Date) {
    self.content = content
    self.role = role
    self.timestamp = timestamp
  }
}
