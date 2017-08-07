struct Repository: Codable {
    let url: String
    let name: String
    let starCount: Int?
    let owner: User
    let description: String?
    let homepage: String?
    let languagesURL: String?
    let contributorsURL: String?

    enum CodingKeys: String, CodingKey {
        case url
        case name
        case starCount       = "stargazers_count"
        case description
        case homepage
        case languagesURL    = "languages_url"
        case contributorsURL = "contributors_url"
        case owner
    }
}
