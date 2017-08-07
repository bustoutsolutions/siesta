struct User: Codable {
    let login, repositoriesURL, avatarURL: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case login
        case name
        case repositoriesURL = "repos_url"
        case avatarURL       = "avatar_url"
    }
}
