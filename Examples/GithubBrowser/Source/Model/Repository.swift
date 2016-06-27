import SwiftyJSON

struct Repository {
    let name: String?
    let starCount: Int?
    let owner: User?

    init(json: JSON) {
        name      = json["name"].string
        starCount = json["stargazers_count"].int
        owner = User(json: json["owner"])
    }
}
