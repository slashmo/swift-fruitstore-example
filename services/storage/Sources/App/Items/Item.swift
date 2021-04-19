struct Item: Identifiable, Hashable, Equatable, Codable {
    let id: Int
    let name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}
