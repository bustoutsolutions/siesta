import SwiftyJSON

struct Repository {
    let url: String
    let name: String
    let starCount: Int?
    let owner: User
    let description: String?
    let homepage: String?
    let languagesURL: String?
    let contributorsURL: String?

    init(json: JSON) throws {
        url             = try json["url"].string.required("repository.url")
        name            = try json["name"].string.required("repository.name")
        starCount       = json["stargazers_count"].int
        description     = json["description"].string
        homepage        = json["homepage"].string
        languagesURL    = json["languages_url"].string
        contributorsURL = json["contributors_url"].string
        owner           = try User(json: json["owner"])
    }
}
