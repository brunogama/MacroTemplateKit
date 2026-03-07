public func loadUser(with id: String) async throws -> User {
  let data = try await api.fetch(id: id)
  return User(from: data)
}
