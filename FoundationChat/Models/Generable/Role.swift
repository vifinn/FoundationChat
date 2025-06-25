import FoundationModels
import SwiftData

@Generable
enum Role: String, Codable, Hashable, CaseIterable {
  case user = "User"
  case assistant = "Assistant"
  case system = "System"
}
