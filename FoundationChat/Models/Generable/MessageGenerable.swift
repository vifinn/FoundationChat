import FoundationModels

@Generable
struct MessageGenerable {
  @Guide(description: "The role of the user who sent the message")
  let role: Role
  @Guide(description: "The content of the message")
  let content: String
}
