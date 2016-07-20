import SwiftyJSON

struct Repository {
    let url: String
    let name: String
    let starCount: Int?
    let owner: User
    let description: String?
    let collaboratorsURL: String?

    init(json: JSON) throws {
        url              = try json["url"].string.required("repository.url")
        name             = try json["name"].string.required("repository.name")
        starCount        = json["stargazers_count"].int
        description      = json["description"].string
        collaboratorsURL = json["collaboratorsURL"].string
        owner            = try User(json: json["owner"])
    }
}
